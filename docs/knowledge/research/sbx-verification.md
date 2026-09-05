---
type: Research
title: sbx 実機検証の結果と未確認事項
description: Docker Sandboxes（sbx）kit の検証ログ・残課題・devcontainer 縮退の判断基準
tags: [sandbox, verification]
timestamp: 2026-09-05T00:00:00Z
---

# sbx 実機検証の結果と未確認事項

`.sandbox/` の kit（[運用手順](/docs/knowledge/runbooks/agent-sandbox-sbx.md)）を実機で確認した結果のスナップショット。spec.yaml は [kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/) に基づく。

## 検証済み（claude テンプレート `docker/sandbox-templates:claude-code-docker`）

環境:

- ベースは Ubuntu 26.04 / arm64、同梱 Node は v22（kit が 24 系へ更新）、`~/.codex` は空、agent ユーザーは passwordless sudo + docker グループ、VM 内 Docker は 29.7.1
- apt の `chromium` は候補なし・`chromium-browser` は snap 移行パッケージのため、kit は Playwright 配布の Chromium を使う（playwright 1.62.1 / Chromium 151.0.7922.34 に固定済み）
- `~/.codex/config.toml` の `${WORKDIR}` はワークスペースの絶対パスへ展開される

挙動:

- **`git push`（https）はヘッダ注入で通る**（`format: "token %s"`）。「push はホスト側で」というフォールバックは不要
- ネットワークの deny-by-default が実際に効く（許可外は 403 `no matching allow rule`）。`GH_TOKEN` は sentinel（`proxy-managed`）で実値は VM に無い
- **`claude mcp add` の既定スコープは local**（cwd 単位）で install ステップの cwd はワークスペースとは限らないため、kit は `-s user` を指定している
- **組み込み claude テンプレートの既定起動コマンドは `claude --dangerously-skip-permissions`**（VM 内の `ps` で実測）。mixin kit だけでは上書きできない
- **組み込みエージェントの認証はプロキシ管理** — `~/.claude/.credentials.json` の `accessToken` / `refreshToken` はいずれも 26 文字で `GH_TOKEN`（13 文字）と同種の sentinel

## clone モードでの再検証（`sbx run claude --clone --kit ./.sandbox/kit`）

チェックリスト 4・6〜12 を全項目パス。clone モード固有の問題は出ていない。

- ワークスペースのパスは **clone モードでもホストの絶対パスをミラーする**。`${WORKDIR}` も同じパスへ展開されるため `config.toml` の `[projects."..."]` は direct モードと同結果。テンプレート由来の `/home/agent/workspace` は空ディレクトリとして残るだけ
- 導入結果: Node v24.19.0 / pnpm 11.9.0 / storeDir `/home/agent/.pnpm-store`（作業ツリーに `.pnpm-store` は作られない）/ Chromium 151.0.7922.34 / `chrome-devtools-mcp` 1.7.0 / `@openai/codex` 0.149.1 / `opencode-ai` 1.18.23 / `codex@openai-codex` プラグイン 1.0.6
- `chrome-devtools` MCP が user スコープで接続 OK。**スクリーンショットで日本語も豆腐にならない**（`fonts-noto-cjk`）
- `CI=true pnpm install --frozen-lockfile` → `pnpm release-check` が通る
- **デフォルトポリシーが `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していない**ことを実測（403）。kit の allow に追加済み
- VM 内で `pkill -f <パターン>` は自分自身のシェルにマッチして落ちる。`agentInstructions` に PID 経由で止めるよう明記した

## 方式 A（`sbx create` + `sbx exec`）の検証

claude テンプレート + Claude Max、`sbx create --clone --kit ./.sandbox/kit claude .` → `sbx exec -it -w "$PWD" <sandbox名> claude --permission-mode auto`。

- `sbx create` はエージェントを起動せず kit の install を完走し、`sbx exec` のプロセスは `ps` 上 `claude --permission-mode auto`（bypass フラグは残らない）
- **サブスクリプション認証はそのまま維持され、再ログインを求められない。** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` はいずれも未設定で、credentials のトークン類は sentinel のまま
- 権限判断が効いていることも確認 — `.credentials.json` を表示しようとしたコマンドが auto モードの classifier に拒否された
- チェックリスト 6〜12 を再走して全項目パス（Node v24.20.0 / pnpm 11.9.0 / Chromium 151.0.7922.34 / MCP 接続 OK / `gh api user`・`git ls-remote`・`git push --dry-run` 成功 / `release-check` 通過）
- **`claude.ai` は 403 を返すが本文は Cloudflare のボットチャレンジ**でポリシーとしては通過（`example.com` / `sentry.io` は拒否のまま）
- kit 由来でない `mcp-gateway`（`http://mcp-gateway.docker.internal/mcp`）が登録・接続されている。sbx 側が用意しているものと思われる
- `claude mcp list` の「claude.ai connectors are disabled because ANTHROPIC_API_KEY or another auth source is set」警告は、プロキシ管理の credential が "another auth source" と判定されているため。無効になるのは claude.ai 側の organization connectors だけで Claude Code の動作には影響しない

## 未確認事項

判明したら spec.yaml とこの節を更新する。

1. **codex / opencode テンプレートでの同挙動** — 確認は claude テンプレートのみ。codex テンプレートが `~/.codex/config.toml` を seed している場合、`onlyIfMissing` により kit 側の設定は入らない
2. **`sbx rm` を跨いだ secret の永続性** — sandbox 名スコープの secret が再作成後も残るかは未確認。作り直したら `gh api user` で再確認する
3. **ホスト側でしか確認できない項目**（VM 内に `sbx` は無い）— チェックリスト 5・13・14 後半
4. **方式 B（fork kit）が未検証** — `sbx kit validate` が通るか、`--kit` の二重指定が両方適用されるか、`ps` から bypass フラグが消えているか、OAuth 非対応の制約がどこで顕在化するか。`entrypoint` / `command` の継承解決は公開されていないため **`ps` での実測を必ず行う**
5. **方式 A の codex 側** — codex テンプレート + ChatGPT サブスクリプションで同手順が通るか

## ホスト試用チェックリスト

併存期間の評価用。**4 の方式 A・6〜12 は clone モードの claude sandbox で実施済み**。残るのは 1〜3・5・13・14 と 4 の方式 B。

1. `sbx version`
2. `sbx login`
3. `sbx kit validate ./.sandbox/kit` / `./.sandbox/claude-auto` / `./.sandbox/codex-approve`（fork kit 2 つは未検証。`extends:` の解決もここで確認）
4. 起動モードの上書き確認。方式 A はサブスクリプション認証のまま起動できること（再ログインを求められないこと）が最重要。方式 B は API キー登録を要求する挙動も見る。いずれも VM 内で `git remote -v` / `ls /run/sandbox/source` が clone モードであること、`ps -eo args | grep claude` に bypass フラグが残っていないことを確認
5. `sbx secret set github --sandbox <sandbox名>` → `sbx secret ls` でスコープが sandbox 単位であること
6. VM 内: `node -v`（24 系）/ `pnpm -v`（11.9.0）/ `cat ~/.config/pnpm/config.yaml`（storeDir が agent の home）/ `chromium-no-sandbox --version`
7. `pnpm install --frozen-lockfile && pnpm test`（TTY 無しで止まる場合は `CI=true`）
8. `claude mcp list` に chrome-devtools が出てスクリーンショットが撮れる（local スコープだと一覧に出ない）
9. `gh api user` が成功し、`echo "$GH_TOKEN"` が sentinel であること。`git ls-remote` / `git push --dry-run` も試す
10. `sbx policy ls` の監査。許可外ドメインへの `curl` が拒否されること
11. Codex も 4 と同じ方式で起動 — `${WORKDIR}` の展開、MCP、`ps` の起動引数を確認
12. `sbx run opencode --clone --kit ./.sandbox/kit` — 起動とタスク実行
13. 抜けて再度入る → 再接続（install が走らない）。`sbx rm` → 作り直しで install が走る。**方式 A では再接続も `sbx exec`**
14. VM 内でコミットして `git push` → GitHub に反映。ホストから `git fetch sandbox-<sandbox名>` でも取り出せること

## devcontainer からエージェントを除去する判断基準

以下がすべて満たされたら、devcontainer を「人間の VS Code 開発環境」へ縮退させる（別 PR）:

- sbx 側で日常タスク一式（テスト / MCP での画面確認 / gh・PR 操作 / Codex・OpenCode の無人実行）が 2〜4 週間、devcontainer にフォールバックせず回っている
- pass-cli の全ユースケース（gh、git push、タスク用 API キー）が credential 注入で代替できている
- 除去範囲を確定できている: `post-create.sh` のエージェント導入 + MCP ブロック、`Dockerfile` の Chromium / pass-cli レイヤ、`compose.yaml` の認証 volume 群、`codex-config.toml`、pass-cli 関連ドキュメント。Pi（sbx 非対応）を使い続けるかもこのとき判断する
