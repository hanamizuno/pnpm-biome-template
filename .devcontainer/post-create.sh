#!/usr/bin/env bash
set -euo pipefail

pnpm install --frozen-lockfile

if ! command -v codex >/dev/null 2>&1; then
  sudo npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"

if [ ! -f "$HOME/.codex/config.toml" ]; then
  cp .devcontainer/codex-config.toml "$HOME/.codex/config.toml"
fi

# Codex を Claude Code のプラグインとして登録し、Claude Code から必要に応じて
# Codex に委譲できるようにする（codex-rescue サブエージェント + /codex スキル）。
# ~/.claude ボリュームは再ビルド後も残るため、インストール済みならスキップして冪等に保つ。
if ! claude plugin list 2>/dev/null | grep -q 'codex@openai-codex'; then
  claude plugin marketplace add openai/codex-plugin-cc || true
  claude plugin install codex@openai-codex
fi

# Chrome DevTools MCP をグローバルインストールし、コンテナ内の headless Chromium で
# 画面の見た目（スクリーンショット・コンソール・ネットワーク）をデバッグできるようにする。
# npx での都度取得にしないのは、隔離モード（egress 遮断）でも動かせるようにするため。
if ! command -v chrome-devtools-mcp >/dev/null 2>&1; then
  sudo npm install -g chrome-devtools-mcp
fi

# Claude Code に登録。~/.claude ボリュームに永続化されるため、登録済みならスキップして冪等に保つ。
# Chromium 本体は Dockerfile の devcontainer ステージで導入済み（--no-sandbox ラッパー経由で起動）。
if ! claude mcp get chrome-devtools >/dev/null 2>&1; then
  claude mcp add chrome-devtools -- chrome-devtools-mcp \
    --headless --isolated --no-usage-statistics \
    --executablePath /usr/local/bin/chromium-no-sandbox
fi
