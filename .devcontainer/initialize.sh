#!/usr/bin/env bash
# コンテナの作成/起動前に「ホスト側」で実行される（initializeCommand）。
# ホストの設定（グローバル gitignore、Claude Code の settings / statusline）を
# ステージングし、post-start.sh がコンテナ内へ反映できるようにする。
# コンテナ起動を絶対にブロックしないこと: どのパスでも exit 0 で終わる。
set -u

STAGE=".devcontainer/host-gitignore"

resolve() {
  local p
  p="$(git config --global --get core.excludesFile 2>/dev/null)"
  case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; esac
  [ -n "$p" ] && [ -f "$p" ] && { printf '%s\n' "$p"; return; }
  p="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
  [ -f "$p" ] && { printf '%s\n' "$p"; return; }
  [ -f "$HOME/.gitignore" ] && printf '%s\n' "$HOME/.gitignore"
}

SRC="$(resolve)"

# 先に前回のステージを削除する: cp -L はコピー元のパーミッションを保持するため、
# 読み取り専用のコピー元（例: Nix store）だと次回の上書きに失敗するステージが残る。
rm -f "$STAGE"

if [ -n "${SRC:-}" ]; then
  # -L でシンボリックリンクを実体化する（例: Nix store / home-manager のターゲット）。
  cp -L "$SRC" "$STAGE" 2>/dev/null && chmod 644 "$STAGE" 2>/dev/null || rm -f "$STAGE"
fi

# --- Claude Code の settings + statusline ------------------------------------
# 認証・状態（~/.claude.json、~/.claude/.credentials.json）は意図的にステージング
# しない。認証はコンテナスコープのボリュームに留める（README 参照）。
CLAUDE_STAGE=".devcontainer/host-claude"
CONTAINER_HOME="/home/vscode"

rm -rf "$CLAUDE_STAGE"

if [ -f "$HOME/.claude/settings.json" ] || [ -f "$HOME/.claude/statusline-command.sh" ]; then
  mkdir -p "$CLAUDE_STAGE"
  if [ -f "$HOME/.claude/settings.json" ]; then
    # ホストのホームパス（statusLine コマンド等）をコンテナのホームに書き換える。
    sed "s|$HOME|$CONTAINER_HOME|g" "$HOME/.claude/settings.json" \
      >"$CLAUDE_STAGE/settings.json" 2>/dev/null || rm -f "$CLAUDE_STAGE/settings.json"
  fi
  if [ -f "$HOME/.claude/statusline-command.sh" ]; then
    cp -L "$HOME/.claude/statusline-command.sh" "$CLAUDE_STAGE/statusline-command.sh" 2>/dev/null \
      && chmod 755 "$CLAUDE_STAGE/statusline-command.sh" 2>/dev/null \
      || rm -f "$CLAUDE_STAGE/statusline-command.sh"
  fi
fi

exit 0
