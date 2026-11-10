# .sandbox

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）でエージェントを microVM 内で動かすための kit。[kit 仕様 v3](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md)（sbx v0.51.0 以上）。

- `kit/` — 共有 mixin（Node + pnpm + Chromium + MCP + Codex / OpenCode CLI + ネットワーク / credential ルール）
- `claude-auto/` / `codex-approve/` — [環境ファイル](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)（`sbxenv.yaml`）。agent・kit・clone モードを固定し、既定の YOLO 起動を差し替える

## 使い方

**ホスト側で実行する**（VM の中からは使えない）。sandbox 名は checkout のディレクトリ名から `claude-<ディレクトリ名>` / `codex-<ディレクトリ名>` になる（`sbx ls` で確認できる）。

```bash
# 作られるもの（sandbox・kit・git remote・起動コマンド）を確認する
sbx env plan ./.sandbox/claude-auto

# 初回は作成して接続、2 回目以降は再接続（変更があるたびに一度だけ承認を求められる）。
# 毎回この形で入る（sbx run / sbx env exec だと既定の YOLO 起動になる）
sbx env run ./.sandbox/claude-auto

# GitHub の fine-grained PAT をこの sandbox にだけ登録（値は対話入力。作成後でも即時に効く）
sbx secret set github --sandbox claude-<ディレクトリ名>

# Codex も同様
sbx env run ./.sandbox/codex-approve

# 一覧 / 停止 / 削除（env rm は VM 内の全状態を消す。push していないコミット、
# この sandbox の secret、sandbox-<sandbox名> リモートも消える）
sbx ls
sbx stop claude-<ディレクトリ名>
sbx env rm ./.sandbox/claude-auto
```

`--` の後ろの引数は起動引数を**丸ごと置き換える**ので、権限フラグも書き直す: `sbx env run ./.sandbox/claude-auto -- --permission-mode auto --continue`。

kit を更新したら `sbx env rm` → `sbx env run` で作り直して反映する。OpenCode は組み込み kit と本 kit が組み合わせられないため、claude sandbox 内の `opencode` CLI を使う。

## ホスト側で変更を確認する

clone モードなので sandbox 内のコミットはホストへ自動では来ない。起動中の sandbox は git-daemon を公開しているので、`sandbox-<sandbox名>` リモートから取る。

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
