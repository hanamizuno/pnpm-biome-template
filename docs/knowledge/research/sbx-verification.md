---
type: Research
title: sbx 実機検証の結果と未確認事項
description: Docker Sandboxes（sbx）kit の検証ログと残課題
tags: [sandbox, verification]
timestamp: 2026-11-09T00:00:00Z
---

# sbx 実機検証の結果と未確認事項

`.sandbox/` の kit と環境ファイル（[運用手順](/docs/knowledge/runbooks/agent-sandbox-sbx.md)）を実機で確認した結果のスナップショット。kit は [kit 仕様 v3](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md)、起動は[環境ファイル](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)に基づく。

## kit 仕様 v3 / 環境ファイルでの検証（sbx v0.51.0、2026-11-09、macOS / Apple Silicon）

`sbx env create` で一時 sandbox を作って確認し、削除済み。

- `sbx kit validate ./.sandbox/kit` が通り、`sbx env plan` で 2 つの環境ファイルが解決できる
- ベースは Docker Hardened Images の **Debian 13**（aarch64）。Node は同梱されず、kit が NodeSource から v24.22.2 を入れる。apt の `chromium` が実体のあるパッケージなので Playwright 経由にはならない（Chromium 156.0.8078.79）
- **kit の install hook がすべて成功する**（claude kit）: pnpm 12.3.4（npm で導入、2026-11-10 に再確認。storeDir は `/home/agent/.pnpm-store`、作業ツリーに `.pnpm-store` は作られない）/ `chrome-devtools-mcp` の user スコープ登録と接続 / `@openai/codex` 0.149.1 / `opencode-ai` 1.18.23 / `codex@openai-codex` プラグイン 1.0.6 / Codex 設定 seed
- `CI=true pnpm install --frozen-lockfile` → `pnpm lint` / `pnpm test` / `pnpm typecheck` が通る
- **`sbx env run` で起動したプロセスは `claude --permission-mode auto`**（`ps` で確認。bypass フラグは残らない）
- **組み込み opencode kit は本 kit と組み合わせられない** — `agent-context@1` を使っており、本 kit の `@2` とは `the two cannot compose` で解決に失敗する
- 以下は姉妹テンプレート python-uv-template で同じ v0.51.0 / 同じ構成の kit で確認したもの:
  - **組み込み codex kit は先に `~/.codex/config.toml` を seed する**（`approval_policy = "never"` / `sandbox_mode = "danger-full-access"`）ため、kit の seed はスキップされる。`sbx env run ./.sandbox/codex-approve` のプロセスは `codex --approve-for-me` で、`codex --help` 上このフラグは workspace-write + 自動レビューを強制する
  - 許可リスト外（`example.com`）は 403 で本文 `Approval required for example.com:443.`。`GH_TOKEN` は secret 未登録でも sentinel（`proxy-managed`）
  - **作成後に登録した secret は即時に効く** — 未登録では `api.github.com/user` が "Requires authentication"、`sbx secret set github --sandbox <名前>`（ダミー値）直後に "Bad credentials" に変わる（ヘッダが注入されている）。再起動不要
  - `sbx env rm` で sandbox・その sandbox の secret・`sandbox-<名前>` git remote が消える
  - `~/.claude/skills` は read-only の virtiofs mount。`additionalWorkspaces` の `readOnly: true` はホストのパスに read-only で mount される。`path` の `~` は展開されない（ファイルからの相対パス扱い）
  - **git identity は継承されない**（`user.name` / `user.email` が未設定。`core.excludesFile` は設定される）

## v2 時代の検証（2026-09、`docker/sandbox-templates:claude-code-docker`）

v0.51.0 より前の、kit 仕様 v2 + Ubuntu 26.04 ベースでの結果。v3 で再測していないものは以下が引き続き参考になる:

- **`git push`（https）はヘッダ注入で通る**（`format: "token %s"`）。`gh api user` / `git ls-remote` / `git push --dry-run` も成功
- **`claude mcp add` の既定スコープは local**（cwd 単位）で install の cwd はワークスペースとは限らないため、kit は `-s user` を指定している（v3 でも user スコープで接続を確認）
- **組み込みエージェントの認証はプロキシ管理** — `~/.claude/.credentials.json` のトークン類は sentinel。サブスクリプション認証（Claude Max）は再ログインを求められずに使えた
- `chrome-devtools` MCP のスクリーンショットで日本語も豆腐にならない（`fonts-noto-cjk`）
- デフォルトポリシーは `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していない（403）。kit の allow に追加済み。`claude.ai` は許可後も Cloudflare のボットチャレンジで 403 を返すがポリシーとしては通過
- VM 内で `pkill -f <パターン>` は自分自身のシェルにマッチして落ちる。エージェント向け指示に PID 経由で止めるよう明記している

## 未確認事項

判明したら spec.yaml とこの節を更新する。

1. **v3 での GitHub 往復** — 実 PAT での `gh api user`、VM 内からの `git push`（https）
2. **`sbx env run` でのサブスクリプション認証** — Claude Max / ChatGPT が再ログイン無しで使えるか（上の確認は起動コマンドまで）
3. **codex sandbox 内での他経路** — `--approve-for-me` 無しで `codex` が起動される経路が無いか（その場合は組み込み kit の YOLO seed で動く）
4. **v3 での MCP スクリーンショット**（日本語フォント込み）

## ホスト試用チェックリスト

1. `sbx version`（v0.51.0 以上）/ `sbx login`
2. `sbx kit validate ./.sandbox/kit` / `sbx env plan ./.sandbox/claude-auto`
3. `sbx env run ./.sandbox/claude-auto` — サブスクリプション認証のまま起動できること（再ログインを求められないこと）が最重要。VM 内で `git remote -v` / `ls /run/sandbox/source` が clone モードであること、`ps -eo args | grep claude` に bypass フラグが残っていないことを確認
4. `sbx secret set github --sandbox <sandbox名>` → `sbx secret ls` でスコープが sandbox 単位であること
5. VM 内: `node -v`（24 系）/ `pnpm -v`（12.3.4）/ `cat ~/.config/pnpm/config.yaml`（storeDir が agent の home）/ `chromium-no-sandbox --version`
6. `CI=true pnpm install --frozen-lockfile && pnpm test`
7. `claude mcp list` に chrome-devtools が出てスクリーンショットが撮れる
8. `gh api user` が成功し、`echo "$GH_TOKEN"` が sentinel であること。`git ls-remote` / `git push --dry-run` も試す
9. `sbx policy ls` の監査。許可外ドメインへの `curl` が `Approval required for …` になること
10. `sbx env run ./.sandbox/codex-approve` — `ps` の起動引数が `codex --approve-for-me`、MCP が見えること
11. 抜けて `sbx env run` で再接続（install が走らない）。`sbx env rm` → `sbx env run` で install が走る
12. VM 内で git identity を設定してコミットし `git push` → GitHub に反映。ホストから `git fetch sandbox-<sandbox名>` でも取り出せること
