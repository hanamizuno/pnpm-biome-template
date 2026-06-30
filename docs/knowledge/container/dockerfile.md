---
type: Container Image
title: Dockerfile
description: base → dev / builder / prod / devcontainer の 5 ステージ構成。本番用は distroless 風に node のみで起動。
resource: ../../../Dockerfile
tags: [docker, multi-stage, nodejs, devcontainer]
timestamp: 2026-06-30T00:00:00Z
---

# ステージ構成

| ステージ | ベース | 用途 |
|---|---|---|
| `base` | `node:24-slim` | corepack + pnpm@11 を有効化、`WORKDIR /app` |
| `dev` | `base` | `compose.dev.yml` から使用。`/workspace` に pnpm install、`pnpm dev` を CMD に |
| `builder` | `base` | `pnpm build` で `dist/` を生成し、本番依存のみ `/prod-modules` に展開 |
| `prod` | `node:24-slim` | `builder` から `dist/` と本番依存をコピーし `node dist/main.js` を起動 |
| `devcontainer` | `mcr.microsoft.com/vscode/devcontainers/base:bookworm` | Node.js + Chromium + AI エージェント CLI のための準備 |

# devcontainer ステージの要点

- `chromium` + `fonts-noto-cjk` + `fonts-liberation` をインストール
- カーネルサンドボックスが使えないため、`/usr/local/bin/chromium-no-sandbox` ラッパーを用意 (`--no-sandbox --disable-dev-shm-usage`)
- AI エージェント CLI の永続化先として `/home/vscode/.claude`, `/home/vscode/.codex`, `/home/vscode/.config/gh` を作成
- `~/.claude.json` を `~/.claude/.claude.json` へシンボリックリンク

# ビルド引数

- `NODE_VERSION` (default: `24`)
- `DEBIAN_VERSION` (default: `bookworm`)

# 関連

- [compose](compose.md) — dev / prod の起動手段。
- [devcontainer](devcontainer.md) — `devcontainer` ステージの呼び出し元。
