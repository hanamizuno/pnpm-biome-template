#!/usr/bin/env bash
set -euo pipefail

# node_modules / pnpm ストアは named volume でホストの bind mount から分離している
# （プラットフォーム固有バイナリの混在によるホスト⇔コンテナの再インストールループ防止）。
# named volume は初回 root 所有で作成されるため、先に所有権を直す（作成済みなら no-op）。
sudo chown vscode:vscode /workspace/node_modules "$HOME/.pnpm-store"

# ストアを bind mount の外に固定:
# - 未指定だと pnpm はプロジェクトと同一 FS にストアを作るため /workspace/.pnpm-store
#   （= ホストの checkout 直下）に漏れる
# - volume なのでリビルド後もダウンロードキャッシュが残る
# pnpm 11 のグローバル設定 (~/.config/pnpm/config.yaml) に直接書く。
# `pnpm config set --global` はグローバル bin ディレクトリが PATH に無い
# 非ログインシェルだと検証エラーで失敗するため使わない。
mkdir -p "$HOME/.config/pnpm"
printf 'storeDir: %s\n' "$HOME/.pnpm-store" > "$HOME/.config/pnpm/config.yaml"

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
