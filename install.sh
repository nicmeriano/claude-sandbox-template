#!/usr/bin/env bash
set -euo pipefail

SANDBOX_DIR="$HOME/.claude-sandbox"

echo "Installing claude-sandbox..."

# Check prerequisites
if ! command -v docker &>/dev/null; then
  echo "Error: docker is not installed." >&2
  exit 1
fi

if ! docker sandbox version &>/dev/null; then
  echo "Error: docker sandbox is not available. Enable it in Docker Desktop settings." >&2
  exit 1
fi

if [ ! -d "$HOME/.claude" ]; then
  echo "Error: ~/.claude/ not found. Run Claude Code at least once first." >&2
  exit 1
fi

# Create directory
mkdir -p "$SANDBOX_DIR"

# Write files (inline so install.sh is self-contained)
cat > "$SANDBOX_DIR/Dockerfile" << 'EOF'
FROM docker/sandbox-templates:claude-code

USER root

# Install pnpm globally via corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy Claude config into agent home
COPY claude-config/ /home/agent/.claude/
RUN chown -R agent:agent /home/agent/.claude/

# Stash settings.json separately — sandbox overwrites it with a dead symlink
COPY claude-config/settings.json /opt/claude-settings.json
COPY inject-config.sh /opt/inject-config.sh
RUN chmod +x /opt/inject-config.sh

USER agent
EOF

cat > "$SANDBOX_DIR/inject-config.sh" << 'EOF'
#!/usr/bin/env bash
AGENT_CLAUDE=/home/agent/.claude
rm -f "$AGENT_CLAUDE/settings.json"
cp /opt/claude-settings.json "$AGENT_CLAUDE/settings.json"
chown agent:agent "$AGENT_CLAUDE/settings.json"
EOF
chmod +x "$SANDBOX_DIR/inject-config.sh"

cat > "$SANDBOX_DIR/.dockerignore" << 'EOF'
rebuild.sh
claude-sandbox
install.sh
.dockerignore
EOF

cat > "$SANDBOX_DIR/rebuild.sh" << 'REBUILD'
#!/usr/bin/env bash
set -euo pipefail

SANDBOX_DIR="$HOME/.claude-sandbox"
CLAUDE_DIR="$HOME/.claude"
CONFIG_DIR="$SANDBOX_DIR/claude-config"

rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

for item in settings.json statusline.sh CLAUDE.md keybindings.json; do
  [ -f "$CLAUDE_DIR/$item" ] && cp "$CLAUDE_DIR/$item" "$CONFIG_DIR/"
done

for dir in skills commands; do
  [ -d "$CLAUDE_DIR/$dir" ] && cp -rL "$CLAUDE_DIR/$dir" "$CONFIG_DIR/"
done

docker build -t my-sandbox "$SANDBOX_DIR"
REBUILD
chmod +x "$SANDBOX_DIR/rebuild.sh"

cat > "$SANDBOX_DIR/claude-sandbox" << 'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

FRESH=false
PROJECT_DIR=""

for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=true ;;
    *) PROJECT_DIR="$arg" ;;
  esac
done

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

"$HOME/.claude-sandbox/rebuild.sh"

STATE_DIR="$HOME/.claude-sandbox/sandboxes"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$(echo -n "$PROJECT_DIR" | shasum -a 256 | cut -c1-16)"

SANDBOX_ID=""
if [ -f "$STATE_FILE" ]; then
  SANDBOX_ID=$(cat "$STATE_FILE")
  if ! docker exec "$SANDBOX_ID" true 2>/dev/null; then
    SANDBOX_ID=""
    rm -f "$STATE_FILE"
  fi
fi

if [ "$FRESH" = true ] && [ -n "$SANDBOX_ID" ]; then
  docker sandbox rm "$SANDBOX_ID" >/dev/null 2>&1 || true
  SANDBOX_ID=""
  rm -f "$STATE_FILE"
fi

if [ -z "$SANDBOX_ID" ]; then
  SANDBOX_ID=$(docker sandbox run -d -t my-sandbox -w "$PROJECT_DIR" claude)
  echo "$SANDBOX_ID" > "$STATE_FILE"
fi

docker exec -u root "$SANDBOX_ID" /opt/inject-config.sh
docker exec -it "$SANDBOX_ID" claude --dangerously-skip-permissions
WRAPPER
chmod +x "$SANDBOX_DIR/claude-sandbox"

# Add to PATH if not already there
SHELL_RC=""
case "$(basename "$SHELL")" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
esac

if [ -n "$SHELL_RC" ] && ! grep -q '.claude-sandbox' "$SHELL_RC" 2>/dev/null; then
  echo 'export PATH="$HOME/.claude-sandbox:$PATH"' >> "$SHELL_RC"
  echo "Added ~/.claude-sandbox to PATH in $SHELL_RC"
fi

# Initial build
echo "Building sandbox image..."
"$SANDBOX_DIR/rebuild.sh"

echo ""
echo "Done! Restart your shell or run:"
echo "  source $SHELL_RC"
echo ""
echo "Usage:"
echo "  claude-sandbox              # sandbox in current directory"
echo "  claude-sandbox ~/project    # sandbox in specific directory"
echo "  claude-sandbox --fresh      # force new sandbox (re-auth required)"
