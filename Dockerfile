# NodeSource セットアップ（devcontainer ステージ）用。FROM のバージョンは digest が固定する
ARG NODE_VERSION=24

# ===== Stage 1: base (corepack + pnpm) =====
# ベースイメージは digest 固定（Dependabot の docker エコシステムが追跡・更新する）
FROM node:24-slim@sha256:cb4e8f7c443347358b7875e717c29e27bf9befc8f5a26cf18af3c3dec80e58c5 AS base

# corepack キャッシュを全ユーザーが読める場所に固定（root でビルドしても
# 非 root ユーザー（node）が pnpm を再ダウンロードせずに使えるように）
ENV COREPACK_HOME=/opt/corepack
RUN corepack enable && corepack prepare pnpm@11.9.0 --activate && chmod -R a+rX /opt/corepack
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
FROM node:24-slim@sha256:cb4e8f7c443347358b7875e717c29e27bf9befc8f5a26cf18af3c3dec80e58c5 AS prod

WORKDIR /app

COPY --from=builder --chown=node:node /prod-modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./package.json

USER node
ENTRYPOINT []
CMD ["node", "dist/main.js"]

# ===== Stage 5: devcontainer =====
FROM mcr.microsoft.com/vscode/devcontainers/base:bookworm@sha256:bb7b81b6e5be17b5267f92f4ffda534fea37dab1df97b5e86c1f9b91da5c0b5d AS devcontainer

ARG NODE_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# corepack キャッシュを全ユーザーが読める場所に固定（root でビルドしても
# vscode ユーザーが post-create で pnpm を再ダウンロードせずに使えるように）
ENV COREPACK_HOME=/opt/corepack
# hadolint ignore=DL3008
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare pnpm@11.9.0 --activate \
    && chmod -R a+rX /opt/corepack

# chrome-devtools-mcp 用の headless Chromium と描画フォント（日本語含む）。
# コンテナ内ではカーネルサンドボックスを利用できないため --no-sandbox を付与する
# ラッパーを用意し、MCP からは executablePath でこれを指定する
# （--disable-dev-shm-usage は /dev/shm が小さい Docker 環境でのクラッシュ対策）。
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium fonts-noto-cjk fonts-liberation \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && printf '#!/bin/sh\nexec /usr/bin/chromium --no-sandbox --disable-dev-shm-usage "$@"\n' \
       > /usr/local/bin/chromium-no-sandbox \
    && chmod +x /usr/local/bin/chromium-no-sandbox

RUN mkdir -p /commandhistory /home/vscode/.claude /home/vscode/.codex /home/vscode/.config/gh \
    && chown -R vscode:vscode /commandhistory /home/vscode/.claude /home/vscode/.codex /home/vscode/.config \
    && ln -sf /home/vscode/.claude/.claude.json /home/vscode/.claude.json \
    && chown -h vscode:vscode /home/vscode/.claude.json

CMD ["sleep", "infinity"]
