ARG DEBIAN_VERSION=bookworm

# ===== Stage 1: development =====
FROM node:24-slim AS dev

RUN corepack enable && corepack prepare pnpm@11 --activate

WORKDIR /workspace

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY . /workspace
RUN pnpm typecheck

CMD ["pnpm", "dev"]

# ===== Stage 2: production =====
FROM node:24-slim AS prod

RUN corepack enable && corepack prepare pnpm@11 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY . /app

ENTRYPOINT []

CMD ["pnpm", "tsx", "src/main.ts"]

# ===== Stage 3: devcontainer =====
FROM mcr.microsoft.com/vscode/devcontainers/base:${DEBIAN_VERSION} AS devcontainer

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare pnpm@11 --activate

RUN mkdir -p /commandhistory /home/vscode/.claude /home/vscode/.config/gh \
    && chown -R vscode:vscode /commandhistory /home/vscode/.claude /home/vscode/.config \
    && ln -sf /home/vscode/.claude/.claude.json /home/vscode/.claude.json \
    && chown -h vscode:vscode /home/vscode/.claude.json

CMD ["sleep", "infinity"]
