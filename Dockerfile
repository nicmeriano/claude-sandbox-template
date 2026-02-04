FROM docker/sandbox-templates:claude-code

USER root

# Install pnpm globally via corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy Claude config into agent home (skills, statusline, commands, etc.)
COPY claude-config/ /home/agent/.claude/
RUN chown -R agent:agent /home/agent/.claude/

# Stash settings.json separately — sandbox overwrites it with a dead symlink
COPY claude-config/settings.json /opt/claude-settings.json
COPY inject-config.sh /opt/inject-config.sh
RUN chmod +x /opt/inject-config.sh

USER agent
