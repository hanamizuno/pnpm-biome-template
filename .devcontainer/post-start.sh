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

# --- Proton Pass (pass-cli): タスク用シークレット ------------------------------
# initialize.sh が .devcontainer/host-proton-pat にステージングした PAT を
# コンテナ内（0600、ワークスペースマウントの外）に永続化する。エージェントは
# .devcontainer/pass-relogin でログイン — セッション失効後の再ログインも — する。
# ここではログインしない。セッションはエージェントが必要になったとき確立する。
# ステージは直後に削除する — ワークスペースマウント内の通常ファイルなので、
# 削除はホスト側のコピーにも反映される。削除は EXIT トラップで行うため、
# 途中の失敗 (set -e) で PAT が残ることはない。ステージが無い場合でも既存の
# コンテナ内コピーは消さない: initializeCommand がスキップされる環境
# （bash の無い Windows ホストなど）で再ログイン手段まで失わないため。
trap 'rm -f .devcontainer/host-proton-pat' EXIT
if command -v pass-cli >/dev/null 2>&1; then
  export PROTON_PASS_SESSION_DIR="${PROTON_PASS_SESSION_DIR:-$HOME/.local/state/proton-pass}"
  # セッション volume のマウントポイントと親ディレクトリの所有権を直す:
  # docker は存在しないマウントポイントを root 所有で作る (Dockerfile が
  # 事前作成するようになる前に作られた volume もこれで修復される)。
  sudo mkdir -p "$PROTON_PASS_SESSION_DIR"
  sudo chown vscode:vscode "$HOME/.local" "$HOME/.local/state" "$PROTON_PASS_SESSION_DIR"
  # 置き場所は ~/.local/state/proton-pass-agent（pass-cli が管理し `logout` で
  # 消え得るセッションディレクトリとは別）。volume ではなく素のコンテナ FS:
  # initialize.sh が `devcontainer up` のたびに再ステージするので、コンテナ
  # 再作成時も再配置される。
  if [ -s .devcontainer/host-proton-pat ]; then
    install -d -m 700 "$HOME/.local/state/proton-pass-agent"
    install -m 600 .devcontainer/host-proton-pat "$HOME/.local/state/proton-pass-agent/pat"
  fi
fi
