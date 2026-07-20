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
# initialize.sh が .devcontainer/host-proton-pat にステージングした PAT で
# pass-cli にログインする（ステージなし = このホストに PAT なし。黙ってスキップ）。
# セッションは named volume に永続化されるため、ログインが走るのは初回起動と
# PAT ローテーション後だけ。ステージは直後に削除する — ワークスペースマウント内の
# 通常ファイルなので、削除はホスト側のコピーにも反映される。
if command -v pass-cli >/dev/null 2>&1; then
  export PROTON_PASS_KEY_PROVIDER="${PROTON_PASS_KEY_PROVIDER:-fs}"
  export PROTON_PASS_SESSION_DIR="${PROTON_PASS_SESSION_DIR:-$HOME/.local/state/proton-pass}"
  # セッション volume のマウントポイントと親ディレクトリの所有権を直す:
  # docker は存在しないマウントポイントを root 所有で作る (Dockerfile が
  # 事前作成するようになる前に作られた volume もこれで修復される)。
  sudo mkdir -p "$PROTON_PASS_SESSION_DIR"
  sudo chown vscode:vscode "$HOME/.local" "$HOME/.local/state" "$PROTON_PASS_SESSION_DIR"
  # PROTON_PASS_PERSONAL_ACCESS_TOKEN が設定されていると `pass-cli login` は
  # PAT ログインフローに入る (--pat フラグで argv に渡すより漏れにくい)。
  # ローカルに残った古いセッション (サーバー側で失効済みなど) があると login が
  # "Already authenticated" で失敗するため、先に logout で消す (セッションが
  # 無ければ logout は無害)。
  if ! pass-cli vault list >/dev/null 2>&1 && [ -s .devcontainer/host-proton-pat ]; then
    pass-cli logout >/dev/null 2>&1 || true
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(cat .devcontainer/host-proton-pat)" \
      pass-cli login
  fi

  # 初回起動時に gh 認証を seed する。この PAT から見える vault それぞれの
  # `github-fine-grained` アイテム（固定名）を順に試す — プロジェクト別 vault は
  # 自分のリポジトリスコープ GitHub PAT をこの名前で持つ運用。best-effort:
  # アイテムが無い、または gh が認証済みならスキップ。
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    pass-cli vault list 2>/dev/null | sed -n 's/^- \[[^]]*\]: //p' |
      while IFS= read -r vault; do
        GH_SEED_TOKEN="pass://$vault/github-fine-grained/token" \
          pass-cli run -- sh -c 'printf %s "$GH_SEED_TOKEN" | gh auth login --with-token' \
          >/dev/null 2>&1 || true
        gh auth status >/dev/null 2>&1 && break
      done || true
  fi
fi
rm -f .devcontainer/host-proton-pat
