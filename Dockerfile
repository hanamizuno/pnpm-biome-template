ARG DEBIAN_VERSION=bookworm

# ===== Stage 1: development =====
FROM node:24-slim AS dev

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /workspace

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . /workspace
RUN pnpm typecheck

CMD ["pnpm", "dev"]

# ===== Stage 2: production =====
FROM node:24-slim AS prod

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . /app

ENTRYPOINT []

CMD ["pnpm", "tsx", "src/main.ts"]

# ===== Stage 3: devcontainer =====
FROM mcr.microsoft.com/vscode/devcontainers/base:${DEBIAN_VERSION} AS devcontainer

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

CMD ["sleep", "infinity"]
