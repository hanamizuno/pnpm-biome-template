ARG NODE_VERSION=24
ARG DEBIAN_VERSION=bookworm

# ===== Stage 1: base (corepack + pnpm) =====
FROM node:${NODE_VERSION}-slim AS base

RUN corepack enable && corepack prepare pnpm@11 --activate
WORKDIR /app

# ===== Stage 2: development (compose.dev.yml で使用) =====
FROM base AS dev

WORKDIR /workspace
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY .npmrc ./
RUN pnpm install --frozen-lockfile

USER node
CMD ["pnpm", "dev"]

# ===== Stage 3: builder (tsc でビルド + 本番依存のみ抽出) =====
FROM base AS builder

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY .npmrc ./
RUN pnpm install --frozen-lockfile

COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN pnpm build

# 本番依存のみ別ディレクトリに展開
RUN pnpm install --prod --frozen-lockfile --ignore-scripts \
    && cp -r node_modules /prod-modules

# ===== Stage 4: production =====
FROM node:${NODE_VERSION}-slim AS prod

WORKDIR /app

COPY --from=builder --chown=node:node /prod-modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./package.json

USER node
ENTRYPOINT []
CMD ["node", "dist/main.js"]

# ===== Stage 5: devcontainer =====
FROM mcr.microsoft.com/vscode/devcontainers/base:${DEBIAN_VERSION} AS devcontainer

ARG NODE_VERSION
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
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
