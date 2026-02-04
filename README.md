# claude-sandbox-template

Custom Docker sandbox template for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that brings your global config (skills, statusline, commands, settings) into the sandbox environment.

## What it does

When you run Claude Code in a [Docker sandbox](https://docs.docker.com/ai/sandboxes/), your `~/.claude/` global config is not available inside the container. This template syncs your config into the sandbox image so skills, custom statusline, commands, and keybindings all work.

**Included from `~/.claude/` (~7MB):**
- `settings.json` — user settings, statusline config
- `statusline.sh` — custom status line script
- `skills/` — all installed skills (symlinks resolved)
- `commands/` — custom commands
- `CLAUDE.md`, `keybindings.json` — if they exist

**Excluded (~2.4GB of ephemeral data):**
- `debug/`, `projects/`, `file-history/`, `shell-snapshots/`, `todos/`, `plans/`, `history.jsonl`, `paste-cache/`, `cache/`, `tasks/`, `summaries/`, `statsig/`, `session-env/`, `downloads/`, `telemetry/`, `plugins/`, `chrome/`

The Dockerfile also installs `pnpm` globally via corepack. Edit the Dockerfile to add any other tools your team needs.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/nicmeriano/claude-sandbox-template/main/install.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/nicmeriano/claude-sandbox-template.git ~/.claude-sandbox
~/.claude-sandbox/install.sh
```

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with [sandbox support enabled](https://docs.docker.com/ai/sandboxes/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and run at least once (so `~/.claude/` exists)

## Usage

```bash
claude-sandbox                          # sandbox in current directory
claude-sandbox ~/dev/repos/my-project   # sandbox in specific directory
claude-sandbox --fresh                  # force new sandbox (re-auth required)
```

Sandboxes are reused across launches (auth credentials persist). Use `--fresh` to force a new one.

## How it works

1. **`rebuild.sh`** selectively copies config files from `~/.claude/` into `claude-config/`, resolving symlinks (e.g. skills pointing to `~/.agents/`). Then builds the Docker image.

2. **`Dockerfile`** extends `docker/sandbox-templates:claude-code` — installs pnpm, copies config into `/home/agent/.claude/`.

3. **`claude-sandbox`** reuses an existing sandbox for the workspace if one is running, or creates a new one. Fixes a `settings.json` issue (see below), then attaches Claude interactively.

### The `settings.json` workaround

Docker sandbox overwrites `~/.claude/settings.json` with a symlink to `/mnt/claude-data/settings.json` at container init. The target directory is root-owned and empty, so the symlink is dead. Everything else we COPY into the image survives — only `settings.json` gets clobbered.

`inject-config.sh` (3 lines) replaces the dead symlink with the real file on each launch. If Docker fixes this upstream, the inject becomes a harmless no-op.

## Customizing

**Add tools to the sandbox:** Edit `Dockerfile` — add `RUN apt-get install ...` or other package managers.

**Change which config files are synced:** Edit the loops in `rebuild.sh`.

**Update config after changing `~/.claude/`:** Just run `claude-sandbox` again — `rebuild.sh` re-syncs on every launch.

## File structure

```
~/.claude-sandbox/
├── Dockerfile          # extends base sandbox image
├── .dockerignore
├── inject-config.sh    # fixes settings.json dead symlink
├── rebuild.sh          # syncs config from ~/.claude/ + builds image
├── claude-sandbox      # main entry point (add to PATH)
├── install.sh          # one-command setup
├── claude-config/      # (generated) config snapshot for docker build
└── sandboxes/          # (generated) sandbox ID state files
```
