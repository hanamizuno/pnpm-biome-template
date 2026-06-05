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

if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
fi

mkdir -p "$HOME/.hermes"

if [ ! -f "$HOME/.hermes/config.yaml" ]; then
  cp .devcontainer/hermes-config.yaml "$HOME/.hermes/config.yaml"
fi
