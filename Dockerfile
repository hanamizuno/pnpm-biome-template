# ===== Stage 1: base (pnpm) =====
# ベースイメージは digest 固定（Dependabot の docker エコシステムが追跡・更新する）
FROM node:24-slim@sha256:cb4e8f7c443347358b7875e717c29e27bf9befc8f5a26cf18af3c3dec80e58c5 AS base

# pnpm は corepack ではなく npm で直接導入する
# （理由は /docs/knowledge/adr/0002-pnpm-without-corepack.md）。
# /usr/local/lib 配下に入るため、root でビルドしても非 root ユーザー（node）が
# そのまま使える。バージョンは package.json の packageManager と揃えること。
RUN npm install -g pnpm@12.3.4 && npm cache clean --force
WORKDIR /app

# ===== Stage 2: development (compose.dev.yml で使用) =====
FROM base AS dev

WORKDIR /workspace
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# node ユーザー。数値 UID なら実行環境（K8s の runAsNonRoot 等）が非 root を検証できる（DL3066）
USER 1000
CMD ["pnpm", "dev"]

# ===== Stage 3: builder (tsc でビルド + 本番依存のみ抽出) =====
FROM base AS builder

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
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

# node ユーザー。数値 UID なら実行環境（K8s の runAsNonRoot 等）が非 root を検証できる（DL3066）
USER 1000
ENTRYPOINT []
CMD ["node", "dist/main.js"]
