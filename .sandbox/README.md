# .sandbox

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）でエージェントを microVM 内で動かすための kit。

- `kit/` — 共有 mixin（Node + pnpm + Chromium + MCP + ネットワーク / credential ルール）
- `claude-auto/` / `codex-approve/` — 既定の YOLO 起動を差し替える fork kit

## 使い方

**ホスト側で実行する**（devcontainer の中からは使えない）。sandbox 名は `sbx ls` で確認できる。

```bash
# sandbox を作る（--clone は必須。エージェントはまだ起動しない）
sbx create --clone --kit ./.sandbox/kit claude .

# 起動する（sbx run で入ると既定の YOLO entrypoint が起動するので毎回この形で入る）
sbx exec -it -w "$PWD" claude-<ディレクトリ名> claude --permission-mode auto

# GitHub の fine-grained PAT をこの sandbox にだけ登録（値は対話入力）
sbx secret set github --sandbox claude-<ディレクトリ名>

# 一覧 / 停止 / 削除（rm は VM 内の全状態を消す。push していないコミットも失われる）
sbx ls
sbx stop <sandbox名>
sbx rm <sandbox名>
```

kit を更新したら `sbx rm` → 作り直しで反映する。

## ホスト側で変更を確認する

`--clone` なので sandbox 内のコミットはホストへ自動では来ない。起動中の sandbox は git-daemon を公開しているので、`sandbox-<sandbox名>` リモートから取る。

```bash
# 一時的に中身だけ確認する
git fetch sandbox-<sandbox名>
git diff HEAD...sandbox-<sandbox名>/<ブランチ名>

# 手元のブランチへ取り込む（初回だけ upstream を張る）
git branch --set-upstream-to=sandbox-<sandbox名>/<ブランチ名> <ブランチ名>
git config branch.<ブランチ名>.pushRemote origin   # push は origin へ向ける

# 以後は fetch + pull で追従する
git fetch sandbox-<sandbox名>
git pull --ff-only
```

sandbox を止める / 消すと git-daemon も消えるので、残したいコミットは先に `origin` へ push しておく。

詳細: [docs/knowledge/runbooks/agent-sandbox-sbx.md](../docs/knowledge/runbooks/agent-sandbox-sbx.md) / 検証状況: [docs/knowledge/research/sbx-verification.md](../docs/knowledge/research/sbx-verification.md)
