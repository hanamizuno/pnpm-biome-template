#!/usr/bin/env bash
set -euo pipefail

# initialize.sh がステージングしたホストのグローバル gitignore を、git の XDG
# デフォルトパスへ反映する。~/.config/git は名前付きボリュームではないため、
# 毎回上書きすることでホストを正とする。
if [ -f .devcontainer/host-gitignore ]; then
  mkdir -p "$HOME/.config/git"
  rm -f "$HOME/.config/git/ignore"
  cp .devcontainer/host-gitignore "$HOME/.config/git/ignore"
fi

# initialize.sh がステージングしたホストの git identity を反映する。
# `git config --global` で書き込むため、コンテナ側の git config（Features が
# 書く safe.directory 等）には触れない。起動ごとに上書きされ、ホストが正。
if [ -f .devcontainer/host-gituser ]; then
  name="$(git config --file .devcontainer/host-gituser --get user.name 2>/dev/null || true)"
  email="$(git config --file .devcontainer/host-gituser --get user.email 2>/dev/null || true)"
  if [ -n "$name" ]; then git config --global user.name "$name"; fi
  if [ -n "$email" ]; then git config --global user.email "$email"; fi
fi

# initialize.sh がステージングした Claude Code 設定を反映する。settings.json は
# 上書きではなく deep-merge（キー単位でホスト優先）にする。コンテナ内では
# Claude Code 自身がこのファイルへ書き込むため、コンテナ専用のキー（プラグイン
# 有効化や /config での変更）をホストが同名キーを定義しない限り残すためである。
# 認証情報はステージングされない。
if [ -f .devcontainer/host-claude/statusline-command.sh ]; then
  mkdir -p "$HOME/.claude"
  rm -f "$HOME/.claude/statusline-command.sh"
  cp .devcontainer/host-claude/statusline-command.sh "$HOME/.claude/statusline-command.sh"
fi

if [ -f .devcontainer/host-claude/settings.json ]; then
  mkdir -p "$HOME/.claude"
  target="$HOME/.claude/settings.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$target" ] &&
    jq -s '.[0] * .[1]' "$target" .devcontainer/host-claude/settings.json >"$target.tmp" 2>/dev/null; then
    mv "$target.tmp" "$target"
  else
    # jq が無い、または既存 settings が無い/不正な場合は単純コピーにフォールバック。
    rm -f "$target.tmp" "$target"
    cp .devcontainer/host-claude/settings.json "$target"
  fi
fi
