FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9 --activate

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install arc binary (binary downloaded in CI from private arc-evolve repo, see docker-build.yml)
COPY arc-bin/arc /usr/local/bin/arc
RUN chmod +x /usr/local/bin/arc

# Copy harness scripts, agents, skills, and identity
COPY scripts/ /opt/arc/scripts/
COPY agents/ /opt/arc/agents/
COPY skills/ /opt/arc/skills/
COPY identity/ /opt/arc/identity/

RUN chmod +x /opt/arc/scripts/*.sh \
    && find /opt/arc/agents -name "*.sh" -exec chmod +x {} \;

COPY entrypoint.sh /opt/arc/entrypoint.sh
RUN chmod +x /opt/arc/entrypoint.sh

ENTRYPOINT ["/opt/arc/entrypoint.sh"]
