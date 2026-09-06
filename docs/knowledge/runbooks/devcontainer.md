---
type: Runbook
title: AI エージェント Dev Container
description: devcontainer のセットアップ・認証・シークレット運用
tags: [devcontainer, agents, security]
timestamp: 2026-09-05T00:00:00Z
---

# AI エージェント Dev Container

Dev Container は人間の開発環境と AI エージェント（Claude Code / Codex 等）の実行環境を兼ねる。ツールチェーンは [Dev Container Features](https://containers.dev/implementors/features/) と `post-create.sh` で Node + pnpm 環境に重ねて注入する。コンテナ定義は `.devcontainer/compose.yaml`（ルートの `compose.yml` / `compose.dev.yml` とは別物）。

より強い隔離が必要な場合は [Docker Sandboxes 運用](/docs/knowledge/runbooks/agent-sandbox-sbx.md) を使う。

## 同梱ツール

Features（`devcontainer.json` で digest 固定）: 共通ユーティリティ（非 root の `vscode` ユーザー + sudo）、GitHub CLI、Claude Code CLI。

`post-create.sh`（冒頭の `AGENTS` 配列で取捨選択。行をコメントアウトするとインストールと関連セットアップをスキップ。反映には rebuild が必要で、認証 volume は残る）:

- Codex CLI と Codex プラグイン（Claude Code から `codex-rescue` サブエージェント / `/codex` スキルで委譲できる）
- OpenCode、Pi
- `chrome-devtools-mcp` を Claude Code に登録（Codex へは `codex-config.toml` で登録）

Node / pnpm / headless Chromium はルート `Dockerfile` の `devcontainer` ステージ側（言語ランタイムは Dockerfile、エージェントツールは Features / post-create）。別の CLI を足すときは、上流 Feature か `post-create.sh` の冪等な `install_<name>` 関数 + `AGENTS` 配列 1 行を追加する（認証を永続化するなら `compose.yaml` の volume も）。

## 初回セットアップ

起動は VS Code の「Reopen in Container」または `devcontainer up --workspace-folder .`。

認証は初回のみ。ホストから bind mount せず固定名の compose named volume（`claude-config` / `codex-config` / `opencode-data` / `opencode-config` / `pi-config` / `gh-config`）に永続化するため、rebuild 後も再ログイン不要。

```bash
devcontainer exec --workspace-folder . claude --permission-mode auto  # 初回はログインフローが出る（/login は渡さない）
devcontainer exec --workspace-folder . codex                          # ChatGPT でサインイン
devcontainer exec --workspace-folder . opencode auth login
devcontainer exec --workspace-folder . pi                             # /login でプロバイダ選択
devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web
```

ホストの `gh` トークンを流し込む場合:

```bash
devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_TOKEN \
  sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
```

API キー課金で使う場合、キーはホストからの環境変数パススルーではなく pass-cli 経由で渡す（後述）。

## ホスト設定の継承

`initialize.sh`（ホスト側で実行）が設定を `.devcontainer/` 配下の git-ignore されたファイルへステージングし、`post-start.sh` がコンテナ内へ反映する。ホストに該当ファイルが無ければ no-op。

- **グローバル gitignore** — `core.excludesFile` → `~/.config/git/ignore` → `~/.gitignore` の順に解決し、シンボリックリンクを実体化してコンテナの `~/.config/git/ignore` へコピー（起動ごとに上書き）
- **git identity** — ホストの `user.name` / `user.email` を値として読み、`git config --global` で反映（credential helper 等は持ち込まない）
- **Claude Code の settings + statusline** — `~/.claude/settings.json` をホームパス書き換えのうえ `jq` で deep-merge、`statusline-command.sh` もコピー。認証・状態（`~/.claude.json`、`.credentials.json`）は意図的に持ち込まない

ステージングされた `host-*` ファイルは個人設定を含むローカル生成物。git clone では出ないが `cp -r` / zip には含まれるので、git 外でコピーするときは除外する。特に `host-proton-pat` は本物のシークレットを一時的に保持するため、残留コピーを見つけたらそのトークンはローテーション対象。

Windows ホストでは `initializeCommand` の実行に Git Bash / WSL が `PATH` 上に必要（無い場合は同期のみスキップ）。

## ローカルオーバーライド（compose.local.yaml）

`dockerComposeFile` は `["compose.yaml", "compose.local.yaml"]`。gitignore 済みの `compose.local.yaml` に差分だけ書けば、コミットせず個人環境向けの bind mount / ネットワーク / extra_hosts を足せる（無い場合は `initialize.sh` が no-op スタブを生成）。相対パスは `.devcontainer/` 基準で、ワークスペースは `..`、隣接ディレクトリは `../../<name>`。

```yaml
services:
  app:
    volumes:
      - ../../<dir>:/<dir>:ro   # target を /<dir> にすると /workspace から ../<dir> で参照できる
```

## 見た目のデバッグ（Chrome DevTools MCP）

エージェントは [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 経由で VM 内の headless Chromium を操作し、`pnpm dev` の画面をスクリーンショット・コンソール・ネットワークで確認できる。

- Claude Code へは `post-create.sh` が `claude mcp add` で登録（rebuild で既存コンテナにも反映）
- Codex へは `codex-config.toml` の `[mcp_servers.chrome-devtools]`。初回作成時のみコピーされるため、既存の `~/.codex/config.toml` には手動追記
- Chromium は Debian の `chromium` パッケージ（arm64 でも動く）+ `fonts-noto-cjk`。コンテナ内ではカーネルサンドボックスが使えないため `--no-sandbox` を付ける `/usr/local/bin/chromium-no-sandbox` ラッパー経由で起動する。信頼できないサイトの閲覧には使わない
- MCP は `--isolated --headless --no-usage-statistics` で起動する

## 隔離の範囲

デフォルトは egress 開放。防御面は「非 root ユーザー」「ワークスペース限定マウント」「コンテナスコープの認証ボリューム」の 3 点で、ホストの認証情報も Docker ソケットも露出しない。エージェントの既定モードは権限チェックを飛ばさず自動判断させる設定（Claude Code は `permissions.defaultMode: "auto"`、Codex は `approval_policy = "on-request"` / `approvals_reviewer = "auto_review"` / `sandbox_mode = "workspace-write"`）。

このテンプレートが提供**しない**もの: 独立カーネル、細粒度のネットワーク allow/deny、ネスト Docker デーモン。必要なら [sbx](/docs/knowledge/runbooks/agent-sandbox-sbx.md) を使う。

egress を止めたい場合は internal ネットワークに繋ぐ（切り替え前に `pnpm install` 等を済ませておく）:

```bash
docker network create --internal agent-internal
```

```yaml
# compose.local.yaml
services:
  app:
    networks: [agent-internal]
networks:
  agent-internal:
    external: true
```

ホストの loopback は意図的に開けていない（`host.docker.internal` を足すと `0.0.0.0` バインドのホストサービスが全部見える）。必要な場合のみ `compose.local.yaml` で `extra_hosts: ["host.docker.internal:host-gateway"]` を足す。

## GitHub 権限の制限（PAT）

エージェントの `gh` は保存済みトークンのスコープをそのまま引き継ぐため、権限は PAT 側でしか絞れない。普段使いの `$GH_TOKEN` ではなく専用 PAT を seed する。

1. GitHub で fine-grained PAT を発行（[事前入力済みテンプレート](https://github.com/settings/personal-access-tokens/new?name=agent-devcontainer&description=Agent%20devcontainer%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write): Contents/PR/Issues Write + Metadata/Actions Read + Workflows Write、90 日）。`Administration: Write` はベースラインに含めない
2. `devcontainer exec --workspace-folder . gh auth logout --hostname github.com`（スコープの累積を防ぐ）
3. トークンを流し込む（値がシェル履歴に残らないようファイル経由が安全）:
   ```bash
   devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT="$(cat ~/.config/agent-gh-pat)" \
     sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   ```
4. `gh auth status` で確認（classic PAT は `curl -sI -H "Authorization: token …" https://api.github.com/user` の `x-oauth-scopes` に出る。fine-grained は空になるので設定画面を見る）

必要権限の目安: 読み取りだけなら Issues/PR/Metadata Read、コメントや PR 操作を足すなら Issues/PR Write、`git push` するなら Contents Write、Actions の dispatch なら Actions Write、workflow YAML を編集させるなら Workflows Write。

注意点:

- fine-grained PAT は `gh` の一部サブコマンドが未対応。403 が返るときは最小スコープの classic PAT にフォールバック
- トークンは volume 内の `~/.config/gh/hosts.yml` に入る。コンテナ侵害 = トークンのスコープ範囲の侵害と見なす
- ローテーションは 2 + 3 の繰り返しで足りる（volume の作り直しは不要）
- `.devcontainer/pass-relogin` は agent vault の `github-fine-grained` アイテムから `gh` 認証を seed する（未認証時のみ）

## タスク用シークレット（Proton Pass / pass-cli）

エージェントは無人で動き、自分の環境変数はすべて読める。環境変数の読み取りはコマンド実行を伴わないため承認機構では止められない。したがってタスク用シークレットを ambient なコンテナ環境変数（`remoteEnv` / `containerEnv` パススルー）に置かないこと。[Proton Pass CLI](https://protonpass.github.io/pass-cli/) でコマンド単位に注入する。

1. `.env`（git-ignore 済み。`example.env` からコピー）には `pass://SHARE_ID/ITEM_ID/FIELD` の参照だけを書く。参照は ID ベースで、vault 名やアイテム名では解決されない。ID は `pass-cli item list --vault-name <vault> --output json` で調べる
2. シークレットが要るコマンドは `PROTON_PASS_AGENT_REASON="<取得理由>" pass-cli run --env-file .env -- <cmd>` で実行する。値は `<cmd>` の環境変数にのみ注入され、stdout/stderr ではマスクされる。`PROTON_PASS_AGENT_REASON` は PAT セッションでは必須で、Proton の監査ログに残る

ログインの仕組み: `initialize.sh` がホストの `~/.config/proton-pass-agent/<ディレクトリ名>`（無ければ `pat`）を `host-proton-pat` としてステージングし、`post-start.sh` がコンテナの `~/.local/state/proton-pass-agent/pat`（0600）へコピーしてステージを削除する。セッションが切れたら `.devcontainer/pass-relogin` がそこから再確立する（セッションは `proton-pass` volume に永続化）。ホストに PAT ファイルが無ければ全ステップがスキップされる。

スコープモデル: PAT は専用 vault（例 `agent-secrets`）だけにスコープした `viewer` ロール・1〜2 週間の有効期限で発行する。vault に入れた = エージェントに渡した、と見なし、中のトークン自体も最小権限にする。マスキングは衛生であって境界ではない（サブプロセスは値をファイルにもネットワークにも出せる）。プロジェクト別に被害半径を切るなら vault と PAT をプロジェクト専用にし、PAT を `~/.config/proton-pass-agent/<ディレクトリ名>` に置く。

ホスト側の初回セットアップ:

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; read -rs PAT; printf '%s' "$PAT" > ~/.config/proton-pass-agent/pat)
```

## node_modules と pnpm ストアの分離

`node_modules` にはプラットフォーム固有バイナリ（biome / esbuild 等）が入るため、ホストとコンテナで共有すると切り替えのたびに再インストールになる。

- `node_modules` は named volume がホスト側ディレクトリをマスクする（双方が別々に保たれる）
- pnpm ストアは `post-create.sh` が volume（`~/.pnpm-store`）へ固定する（未指定だとホストの checkout 直下に `.pnpm-store/` が漏れる）

やり直すときはコンテナ内で `rm -rf node_modules && pnpm install`（ホストに影響しない）。ストアと `node_modules` は別マウントなので hardlink は効かず、pnpm は copy にフォールバックする。

## その他

- Feature 更新の取り込み: `devcontainer up --workspace-folder . --remove-existing-container`（VS Code なら Rebuild Container）
- ホストの Docker ソケットはマウントしていないため、エージェントはホストのコンテナを操作できない
