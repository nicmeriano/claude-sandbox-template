#!/usr/bin/env bash
# Fix settings.json: sandbox overwrites it with a dead symlink
# pointing to unwritable /mnt/claude-data/settings.json.
# The real settings.json is already COPY'd into the image at build time,
# so we just need to restore it from the Docker layer.
AGENT_CLAUDE=/home/agent/.claude
rm -f "$AGENT_CLAUDE/settings.json"
cp /opt/claude-settings.json "$AGENT_CLAUDE/settings.json"
chown agent:agent "$AGENT_CLAUDE/settings.json"
