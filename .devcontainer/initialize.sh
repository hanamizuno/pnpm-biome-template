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
# しない。認証はコンテナスコープのボリュームに留める（docs/knowledge/runbooks/devcontainer.md 参照）。
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
# ホストの 0600 ファイルから Proton Pass の PAT を取り出し、上記と同じ git-ignore
# の host-* ステージング方式で置く。post-start.sh がコンテナ内に永続化するため、
# pass-cli のセッションが失効してもエージェントが自力で再ログインできる。
# ステージはその直後に削除される。ホストにファイルが無ければ何もステージングされず、
# コンテナは pass-cli のシークレットなしで通常どおり動く。
# docs/knowledge/runbooks/devcontainer.md「タスク用シークレット」を参照。
# 参照はプロジェクト別 (~/.config/proton-pass-agent/<ディレクトリ名>) を先に探し、
# 無ければ共有デフォルト (~/.config/proton-pass-agent/pat) にフォールバックする。
# プロジェクト別ファイルを置くだけで、そのプロジェクトを専用 vault の PAT に
# opt-in できる (リポジトリ側の設定は不要)。
PAT_STAGE=".devcontainer/host-proton-pat"
PAT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/proton-pass-agent"
rm -f "$PAT_STAGE"
for PAT_SRC in "$PAT_DIR/$(basename "$PWD")" "$PAT_DIR/pat"; do
  if [ -f "$PAT_SRC" ]; then
    umask 077
    cp "$PAT_SRC" "$PAT_STAGE" 2>/dev/null || rm -f "$PAT_STAGE"
    break
  fi
done
[ -f "$PAT_STAGE" ] ||
  echo "initialize.sh: $PAT_DIR に PAT ファイルが無いため、コンテナ内で pass-cli ログインは利用できません" >&2

# ステージを正規化する: 紛れ込んだ CR/LF（トークンと一緒に貼り付けた改行など）を
# 除去し、pst_<token>::<key> 形式のものだけを残す — それ以外は警告付きで破棄し、
# 不正な PAT がコンテナ起動をブロックしないようにする。
if [ -s "$PAT_STAGE" ]; then
  PAT="$(tr -d '\r\n' <"$PAT_STAGE")"
  case "$PAT" in
    pst_*::*) printf '%s' "$PAT" >"$PAT_STAGE" ;;
    *)
      rm -f "$PAT_STAGE"
      echo "initialize.sh: PAT ファイルが pst_<token>::<key> 形式ではないため pass-cli ログインは利用できません" >&2
      ;;
  esac
  unset PAT
fi

exit 0
