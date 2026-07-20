#!/usr/bin/env bash
# コンテナの作成/起動前に「ホスト側」で実行される（initializeCommand）。
# ホストの設定（グローバル gitignore、Claude Code の settings / statusline）を
# ステージングし、post-start.sh がコンテナ内へ反映できるようにする。
# コンテナ起動を絶対にブロックしないこと: どのパスでも exit 0 で終わる。
set -u

# --- compose.local.yaml stub --------------------------------------------------
# dockerComposeFile に列挙された compose.local.yaml（gitignore、ローカル
# オーバーライド）が無いと docker compose が起動できないため、no-op スタブを作る。
COMPOSE_LOCAL=".devcontainer/compose.local.yaml"
[ -f "$COMPOSE_LOCAL" ] || printf 'services:\n  app: {}\n' > "$COMPOSE_LOCAL"

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

# --- Git identity (user.name / user.email) -----------------------------------
# ファイルではなく値を読むことで includes / conditional includes を解決させ、
# credential helper などホスト専用の設定は持ち込まずに identity だけを継承する。
GITUSER_STAGE=".devcontainer/host-gituser"

rm -f "$GITUSER_STAGE"

GIT_NAME="$(git config --global --get user.name 2>/dev/null)"
GIT_EMAIL="$(git config --global --get user.email 2>/dev/null)"
if [ -n "$GIT_NAME" ]; then
  git config --file "$GITUSER_STAGE" user.name "$GIT_NAME" 2>/dev/null || rm -f "$GITUSER_STAGE"
fi
if [ -n "$GIT_EMAIL" ]; then
  git config --file "$GITUSER_STAGE" user.email "$GIT_EMAIL" 2>/dev/null || rm -f "$GITUSER_STAGE"
fi

# --- Proton Pass の PAT（タスク用シークレット） --------------------------------
# macOS の Keychain から Proton Pass の PAT を取り出し、上記と同じ git-ignore の
# host-* ステージング方式で置く。post-start.sh がコンテナ内で pass-cli にログイン
# した直後にステージを削除する。Keychain 未登録、または `security` 自体が無い
# 環境（Linux / Windows）では何もステージングされず、コンテナは pass-cli の
# シークレットなしで通常どおり動く。
# README「タスク用シークレット（Proton Pass / pass-cli）」を参照。
# Keychain の参照はプロジェクト別 (proton-pass-agent-pat-<ディレクトリ名>) を先に
# 探し、無ければ共有デフォルト (proton-pass-agent-pat) にフォールバックする。
# プロジェクト別アイテムを登録するだけで、そのプロジェクトを専用 vault の PAT に
# opt-in できる (リポジトリ側の設定は不要)。
PAT_STAGE=".devcontainer/host-proton-pat"
rm -f "$PAT_STAGE"
if command -v security >/dev/null 2>&1; then
  umask 077
  PROJECT_SERVICE="proton-pass-agent-pat-$(basename "$PWD")"
  security find-generic-password -w -s "$PROJECT_SERVICE" >"$PAT_STAGE" 2>/dev/null ||
    security find-generic-password -w -s proton-pass-agent-pat >"$PAT_STAGE" 2>/dev/null || {
      rm -f "$PAT_STAGE"
      echo "initialize.sh: Keychain に $PROJECT_SERVICE も proton-pass-agent-pat も未登録のため pass-cli ログインはスキップされます" >&2
    }
fi

exit 0
