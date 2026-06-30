---
type: Dev Container
title: Dev Container
description: AI エージェント CLI (Claude Code / Codex / GitHub CLI) と Chrome DevTools MCP を備える VS Code Dev Container。
resource: ../../../.devcontainer/devcontainer.json
tags: [devcontainer, ai-agents, chromium, mcp]
timestamp: 2026-06-30T00:00:00Z
---

# 構成

`Dockerfile` の `devcontainer` ステージをベースに、Dev Container Features と post-create / post-start フックで AI エージェント環境を重ねる。

## ホスト設定の継承

`.devcontainer/initialize.sh` がホスト側で実行され、以下をステージング。`post-start.sh` でコンテナ内へ反映する:

- グローバル `.gitignore`
- git identity (`user.name` / `user.email`)
- Claude Code の `settings.json` / statusline

## エージェント CLI 注入

- Dev Container Features と `post-create.sh` で以下を注入:
  - Claude Code
  - Codex CLI (`.devcontainer/codex-config.toml` を `~/.codex` ボリュームへコピー、MCP 登録含む)
  - GitHub CLI

## Chrome DevTools MCP

- headless Chromium (`chromium-no-sandbox` ラッパー) + [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- エージェントは開発サーバーの画面をスクリーンショット等で観察できる

# 関連ファイル

- [`.devcontainer/devcontainer.json`](../../../.devcontainer/devcontainer.json) — Features / mounts / フック登録
- [`.devcontainer/initialize.sh`](../../../.devcontainer/initialize.sh) — initialize フック (ホスト側で実行)
- [`.devcontainer/post-create.sh`](../../../.devcontainer/post-create.sh) — post-create フック (pnpm install + CLI セットアップ)
- [`.devcontainer/post-start.sh`](../../../.devcontainer/post-start.sh) — post-start フック (ホスト設定の反映)
- [`.devcontainer/codex-config.toml`](../../../.devcontainer/codex-config.toml) — Codex CLI 初期設定

# 関連

- [dockerfile](dockerfile.md) — `devcontainer` ステージの中身。
- [compose](compose.md) — 通常の Docker Compose 経由でも開発可能。
