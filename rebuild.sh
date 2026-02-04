#!/usr/bin/env bash
set -euo pipefail

SANDBOX_DIR="$HOME/.claude-sandbox"
CLAUDE_DIR="$HOME/.claude"
CONFIG_DIR="$SANDBOX_DIR/claude-config"

# Clean previous config snapshot
rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

# Copy individual config files (if they exist)
for item in settings.json statusline.sh CLAUDE.md keybindings.json; do
  [ -f "$CLAUDE_DIR/$item" ] && cp "$CLAUDE_DIR/$item" "$CONFIG_DIR/"
done

# Copy config directories (-L resolves symlinks, e.g. skills pointing to ~/.agents/)
for dir in skills commands; do
  [ -d "$CLAUDE_DIR/$dir" ] && cp -rL "$CLAUDE_DIR/$dir" "$CONFIG_DIR/"
done

# Build the image
docker build -t my-sandbox "$SANDBOX_DIR"
