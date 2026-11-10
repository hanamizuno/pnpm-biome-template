---
type: Runbook
title: AI エージェント Sandbox（Docker Sandboxes / sbx）
description: sbx で microVM 隔離のエージェント実行環境を運用する手順（環境ファイル / kit 仕様 v3）
tags: [sandbox, agents, security]
timestamp: 2026-11-09T00:00:00Z
---

# AI エージェント Sandbox（Docker Sandboxes / sbx）

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）で AI エージェントを microVM 内で実行する構成。kit は `.sandbox/` にある。本テンプレートのエージェント実行環境はこれに一本化している。

保証:

- **microVM 境界** — 独立カーネル。コンテナエスケープにつながる脆弱性も封じ込める
- **deny-by-default のネットワーク** — 外向き TCP は許可リストのドメインのみ（UDP / ICMP は遮断）
- **credential 非搬入** — トークンはホスト側プロキシが HTTP ヘッダに注入し、実値が VM に入らない
- **sandbox ごとの Docker デーモン** — ホストの Docker に触れない

検証状況と未確認事項は [sbx 実機検証](/docs/knowledge/research/sbx-verification.md) を参照。

> `sbx` は**ホスト OS 上で実行する**。VM の中からは使えない。

## 前提とインストール

macOS 14+ / Apple Silicon、Windows 11、Ubuntu 24.04+（KVM 有効）。Docker Desktop / Engine は不要（既存の Colima 等とも共存可）。

```bash
brew install docker/tap/sbx   # macOS。他 OS は公式ドキュメント参照
sbx version                   # v0.51.0 以上（組み込みエージェントが v3 kit になった版）
sbx login                     # 必須。未サインインだと各コマンドが認証エラーで失敗する
```

初回にデフォルトのネットワークポリシー選択を求められることがある。kit が必要ドメインを allow で足すので **Locked Down か Balanced** を選ぶ。

## 初回セットアップ

起動は[環境ファイル](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)（`sbxenv.yaml`、sbx v0.51.0+ の experimental 機能）から行う。環境ファイルが agent・kit（`../kit`）・ワークスペース（`../..` = リポジトリルート）・clone モード・起動コマンドをまとめて固定するので、`--clone` や `--kit` の付け忘れが起きない。

```bash
cd <このリポジトリの checkout>

# 0) 未コミットの変更はクローンに入らないので、先にコミットしておく

# 1) 作られるもの（sandbox・kit・git remote・起動コマンド）を確認する
sbx env plan ./.sandbox/claude-auto

# 2) 初回は作成して接続、2 回目以降は再接続（変更があるたびに一度だけ承認を求められる）。
#    毎回この形で入る（sbx run / sbx env exec だと YOLO 起動になる）
sbx env run ./.sandbox/claude-auto

# 3) GitHub の fine-grained PAT をその sandbox にスコープして登録（値は対話入力）。
#    作成後の登録でも即時に効く（作り直し不要）
sbx secret set github --sandbox claude-<ディレクトリ名>

# Codex も同様
sbx env run ./.sandbox/codex-approve
sbx secret set github --sandbox codex-<ディレクトリ名>
```

環境ファイルは `name:` を書いていないので、sandbox 名は `<agent>-<ワークスペースのディレクトリ名>`（例: `claude-pnpm-biome-template`）になり、テンプレートから作ったプロジェクトごとに別の sandbox になる。並行作業したいときだけ `--name` で名前を付ける（その sandbox に対する `sbx env` コマンドすべてに同じ `--name` が要る）。初回はエージェントごとの認証（ブラウザログイン等）が必要で、VM 内の状態は削除まで永続する。

> **`-g`（グローバル）は使わない。** グローバル登録は他リポジトリの sandbox にも注入され得るため、「リポジトリごとに権限を区切る」方針に反する。`sbx secret set` の引数形式は CLI バージョンで異なるので、差異が出たら `sbx secret set --help` を見る。

kit（`.sandbox/kit/spec.yaml`）が作成時にセットアップするもの: Node 24 + pnpm（corepack 非経由）、headless Chromium + 日本語フォント + `chromium-no-sandbox` ラッパー、`chrome-devtools-mcp` の登録、Codex 設定 seed（既存があれば上書きしない）、委譲先 CLI（Codex / OpenCode）と Claude Code への Codex プラグイン登録、ネットワーク許可リスト（install / runtime フェーズ別）と GitHub PAT のヘッダ注入設定、エージェント向け指示（`~/.claude/kits-agent-context/kit.md` に配置される）。

### `sbx env` コマンド

| コマンド | 動作 |
|---|---|
| `sbx env plan <dir>` | 適用したときに作られるもの（sandbox・kit・git remote・起動コマンド・ホストで走るコマンド）を表示する。何も適用しない |
| `sbx env run <dir>` | sandbox が無ければ作成（kit の install hook を実行）してから、環境ファイルの起動コマンドで接続する。既存なら起動して再接続するだけ |
| `sbx env create <dir>` | 作成だけして接続しない |
| `sbx env exec <dir> -- <cmd>` | sandbox 内でコマンドを実行する（起動コマンドの上書きは**効かない**） |
| `sbx env rm <dir>` | sandbox と、その sandbox にスコープした secret、`sandbox-<名前>` git remote を削除する |

複数のパスを渡すと順に deep-merge される（後のファイルが勝つ。`entrypoint` / `cmd` は連結ではなく置換）。個人用の差分（追加マウント等）は gitignore 済みの `.sandbox/local.yaml` に書いて `sbx env run ./.sandbox/claude-auto ./.sandbox/local.yaml` のように重ねる。kit・ワークスペース・secret の変更は作成時にしか反映されない（`sbx env rm` → run）。`entrypoint` / `cmd` は run のたびに反映される。

## YOLO 既定の上書き

組み込みエージェント（`docker.io/sbx/<agent>:latest` の v3 kit。`sbx kit inspect docker.io/sbx/claude:latest` の「Run Options」で確認できる）の既定は `claude --dangerously-skip-permissions` / `codex --dangerously-bypass-approvals-and-sandbox`。本テンプレートでは `claude --permission-mode auto`（判断はモデルに委ねるが bypass はしない）/ `codex --approve-for-me`（workspace-write を保ち、承認要求を自動レビューへ回す）に差し替える。

**`sbx run claude -- <args>` では上書きできない** — 引数は既定フラグの後ろに追加されるだけで、bypass フラグは残る。また v3 では mixin が workload の起動コマンドを変えられず、fork（`extends`）も無い。そのため環境ファイルの `entrypoint` / `cmd` で `sbx env run` の起動コマンドを丸ごと置き換える:

```yaml
entrypoint: [claude]
cmd: [--permission-mode, auto]
```

- `entrypoint` と `cmd` の**両方**を明示しているのは、省略したフィールドは組み込み kit の既定（bypass フラグ）を継承するため
- **`--` の後ろの引数は `cmd` を丸ごと置き換える。** 引数を足すときは `sbx env run ./.sandbox/claude-auto -- --permission-mode auto --continue` のように権限フラグも書き直す
- 上書きが効くのは `sbx env run` だけ。`sbx run` / `sbx env exec` / `sbx exec` は既定の YOLO 起動になるので、**再接続も `sbx env run` で行う**
- サブスクリプション認証（Claude Max / ChatGPT）はそのまま使える。環境ファイルは組み込みエージェントを選ぶだけで置き換えないため、プロキシ管理の OAuth は変わらない

確認は VM 内で `ps -eo args | grep -E '^(claude|codex)'` — 差し替え後のコマンドが出て、bypass フラグが**残っていない**こと。

> v0.51.0 より前は `sbx create` + `sbx exec`（旧方式 A）か、組み込みエージェントを `extends` する fork kit（旧方式 B）を使っていた。fork kit は `"claude" is no longer a built-in agent` で読み込めなくなった。`sbx create --clone --kit ./.sandbox/kit claude .` + `sbx exec` は v3 kit でも使えるはずだが（未検証）、`--clone` と kit を固定できる環境ファイルに置き換えた。

OpenCode は既定で暗黙のフラグが無いが、組み込み opencode kit は `agent-context@1` を使っており、本 kit（`@2`）とは組み合わせられない（`sbx env create` が `the two cannot compose` で失敗する）。OpenCode は claude sandbox に同居させた CLI として使う（後述「オーケストレーション」）。

### 設定ファイルとの関係

`.claude/settings.json` と Codex の `config.toml` seed も同じ方針に揃えてあるが、**起動時フラグの方が強い**。さらに組み込み claude kit は VM 内の `~/.claude/settings.json` に `"defaultMode": "bypassPermissions"` を書き込むので、リポジトリ側の設定が優先されることを期待せず、常にフラグで明示する。

**codex sandbox では組み込み codex kit が先に `~/.codex/config.toml` を seed する**（`approval_policy = "never"` / `sandbox_mode = "danger-full-access"`）。kit の seed はスキップされるので、`--approve-for-me`（workspace-write + 自動レビューを強制する）が唯一の歯止めになる。その sandbox 内で別経路から素の `codex` を起動すると YOLO になる点に注意。

## kit 仕様 v3

sbx v0.51.0 で組み込みエージェント名が公開 v3 kit に解決されるようになり、**v1/v2 の kit は組み合わせられなくなった**。`kit/spec.yaml` は先頭行 `# syntax=docker/sandbox-kit:3` の v3 mixin。v2 からの主な対応:

| v2 | v3 |
|---|---|
| `name` | なし（identity は参照名）。`displayName` / `description` のみ |
| `setup.install[]` | `com.docker.sandbox/lifecycle@1` の `install[]` |
| `setup.files[]`（`onlyIfMissing`） | `lifecycle@1` の `files[]`（`overwrite: false`）。本 kit は Codex seed を install hook で書いている（後述） |
| `${WORKDIR}` | hook の `env: [WORKSPACE_DIR]` で受け取る |
| `permissions.network.allow` | `com.docker.sandbox/network-policy@1` の `install.allow` / `runtime.allow` |
| `credentials[]` | `com.docker.sandbox/credential@1`（`phase: runtime`、`optional: true`） |
| `agentInstructions` | `com.docker.sandbox/agent-context@2` |

v3 で挙動が変わった点:

- **install フェーズのネットワークは runtime と別管理。** install hook 実行中だけ `install.allow` が開き、エージェント起動前に閉じる。hook に取得元を足したら `install.allow` にも足す
- **hook の環境変数は deny-by-default。** 基本変数（`PATH` / `HOME` 等）と proxy・証明書設定以外は `env` に名前を列挙する
- **`lifecycle.files` の `${{ kit.env.WORKSPACE_DIR }}` は組み込み claude kit では展開エラーになる**（最終環境に `WORKSPACE_DIR` が無い）。そのため Codex 設定は install hook で書いている
- **ベースイメージは Docker Hardened Images の Debian 13**（Node は同梱されないので kit が NodeSource から入れる。apt の `chromium` が実体のあるパッケージなので Playwright 経由にはならない）
- Dockerfile（`RUN`）を持たない descriptor のみの mixin なので、ローカルディレクトリをそのまま使える。検証は `sbx kit validate ./.sandbox/kit`（sandboxd 経由。`--offline` は v3 のソース kit を扱えない）
- v0.51.0 より前に作った sandbox は v2 構成のまま残る。削除して作り直す

## 日常運用

- 同じ checkout で `sbx env run` すると既存 sandbox に再接続する（install は再実行されない）
- `sbx ls` で一覧、`sbx stop <name>` で停止、`sbx env rm ./.sandbox/<環境>` で削除（**VM 内の全状態が消える** — push していないコミットも、その sandbox の secret も失われる）
- kit を更新したら `sbx env rm` → `sbx env run` で作り直して反映する（install hook は作成時にしか走らない）

## clone モードで運用する

`sbx run` の既定は direct モード（ホストの FS をパススルー）だが、**このテンプレートでは clone モードを必ず使う**（環境ファイルの `workspace.clone: true`。`--clone=false` で上書きしないこと）。direct モードには両立しない問題がある:

1. `node_modules` がホストと共有され、macOS バイナリと Linux バイナリが衝突する。sandbox 側の `pnpm install` がホストの `node_modules` を上書きするため運用ルールでは防げず、`.pre-commit-config.yaml` の `language: system` hooks がホストの darwin バイナリを要求することと両立しない。既存 `node_modules` があると `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` で止まりもする
2. virtiofs が symlink の `st_size` を 0 と報告する。`CLAUDE.md`（→ `AGENTS.md`）のようなリンクが「中身が消えた」差分に出て、気付かずコミットすると壊れたファイルが記録される
3. `node_modules` の I/O が virtiofs 越しで遅い

clone モードではワークスペースが VM 内の独立した git クローン（worktree ではない）になるため、いずれも起きない。

運用上の違い:

- **未コミットの変更と gitignore されたファイルはクローンに入らない。** 作業中の変更があるなら先にコミットする
- **成果は push で受け取る。** `git push`（https）はプロキシのヘッダ注入で通るので、ブランチを push して PR にするのが基本経路
- push せずホストへ取り出すなら、sandbox が公開する git-daemon から取る（起動中のみ有効）: `git fetch sandbox-<sandbox名>`
- 逆に sandbox 作成後にホストへ積んだコミットを取り込むには、read-only bind mount されたホストリポジトリから取る（`origin` は GitHub を指すのでホストの未 push コミットは含まれない）: `git fetch /run/sandbox/source`
- **sandbox の削除は push していないコミットを消す。** 長時間の無人実行ではこまめに push させる

## ホストの別フォルダを参照させる

追加のフォルダは環境ファイルの `additionalWorkspaces` で宣言する。個人のパスはコミットする環境ファイルに書かず、gitignore 済みの `.sandbox/local.yaml` に書いて重ねる:

```yaml
# .sandbox/local.yaml — sbx env run ./.sandbox/claude-auto ./.sandbox/local.yaml
schemaVersion: "1"
additionalWorkspaces:
  - path: /Users/me/develop/other-repo   # 絶対パスで書く（`~` は展開されず、相対パスはこのファイルの場所から解決される）
    readOnly: true
```

- 追加ワークスペースは clone の対象外で常に direct mount。VM 内ではホストの絶対パスのまま見える
- **参照目的なら必ず `readOnly: true` を付ける** — direct mount なので上記の direct モードの問題がそのまま当てはまる（書き込みがホストへ即反映される / symlink を壊したコミットが生まれ得る）。`node_modules` を含むフォルダは渡さない
- ワークスペースの追加は作成時のみ。あとから足すには作り直し

他の受け渡し手段: 単発ファイルは `sbx cp ./config.json <sandbox名>:/home/agent/`（逆方向も可）、このリポジトリの最新コミットは `/run/sandbox/source`。

## sbx が自動で継承するもの

ホスト設定のうち sbx 側が組み込みで VM へ持ち込むものは、v3 で減った（v0.51.0 の claude kit で実測）:

- **git identity（`user.name` / `user.email`）は継承されない**（v2 ではホストの値が入っていた）。エージェントにコミットさせる前に sandbox 内で一度 `git config --global user.name …` / `user.email …` を設定する
- グローバル gitignore は `core.excludesFile` に設定される
- `~/.claude/skills` はホストから **read-only の virtiofs mount**（v2 は rw だった）。環境ファイルの `sandboxOptions.skills` で `readwrite` / `off` にできる

継承されない（VM 内で新規に作られる）もの: `~/.claude/settings.json`、`statusline-command.sh`、`~/.claude.json`。リポジトリの `.claude/settings.json` は clone で入るが `settings.local.json` は入らない。

ホスト固有の Claude Code 設定を持ち込む手段は 3 つ。チームで共有したいものは kit の `lifecycle.files`（リポジトリにコミットされる）、個人設定は `sbx cp`（作り直すたびに再実行）、参照させたいだけのファイル群は追加ワークスペース `readOnly: true`（**`~/.claude` を丸ごと渡さないこと** — `.credentials.json` にホストの実トークンが含まれる）。

```bash
sbx cp ~/.claude/statusline-command.sh <sandbox名>:/home/agent/.claude/statusline-command.sh
```

`settings.json` を丸ごと上書きしないこと（組み込み kit が作成時に書き込む内容が消える）。必要なキーだけ追記し、ホームのパスは `/home/agent` に書き換える。`sbx cp` したファイルの所有者はホストの uid になる（読み取りは可能）。

## ネットワークポリシーの監査

外向き通信は deny-by-default だが、**デフォルトの許可リストには広い wildcard が含まれる**。初回に `sbx policy ls` で確認すること。kit の `runtime.allow` はデフォルトへの追加であり、広い許可を削るものではない（絞るのはホスト側の `sbx policy` 操作。deny は allow より優先される）。

VM 内からのプローブでは、**HTTP ステータスではなく本文で判別する**。許可済みドメインでも 4xx は普通に返る（`claude.ai` は Cloudflare のボットチャレンジで 403、`api.anthropic.com` は GET `/` に 404）。拒否は 403 で、本文が `Approval required for <host>:<port>.` になる（v0.51.0 で確認）。

```bash
curl -s https://example.com/ | head -1
# Approval required for example.com:443.
```

デフォルトポリシーは `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していないため、kit の allow に追加してある。テレメトリ系（`sentry.io` 等）は拒否のままが望ましい。

## GitHub 権限の制限（PAT）

エージェントの `gh` / `git push` は注入されるトークンのスコープをそのまま使うため、権限は PAT 側でしか絞れない。普段使いのトークン（`gh auth token`）ではなく、sandbox 専用の fine-grained PAT を `sbx secret set github --sandbox <sandbox名>` で登録する。

- 発行: [事前入力済みテンプレート](https://github.com/settings/personal-access-tokens/new?name=agent-sandbox&description=Agent%20sandbox%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write)（Contents/PR/Issues Write + Metadata/Actions Read + Workflows Write、90 日）。`Administration: Write` はベースラインに含めない
- 必要権限の目安: 読み取りだけなら Issues/PR/Metadata Read、コメントや PR 操作を足すなら Issues/PR Write、`git push` するなら Contents Write、Actions の dispatch なら Actions Write、workflow YAML を編集させるなら Workflows Write
- fine-grained PAT は `gh` の一部サブコマンドが未対応。403 が返るときは最小スコープの classic PAT にフォールバック
- ローテーションは `sbx secret set` で差し替えるだけでよい（sandbox-scoped の secret は実行中でも即時反映）

## タスク用シークレット

sbx のネイティブ機構（ホスト側プロキシによる credential 注入）を使う。

```bash
sbx secret set example --sandbox <sandbox名>   # 名前は kit の credentials の service 名に合わせる
```

kit に `credential@1` のエントリを追加すると（spec.yaml にコメントアウトの雛形あり。inject 先ドメインは `runtime.allow` にも足す）、指定ドメイン宛のリクエストにのみホスト側プロキシがヘッダを注入する。VM 内の環境変数には sentinel 値が入る。kit の変更反映には作り直しが要るが、sandbox-scoped の secret は作成後の登録でも実行中に即時反映される（v0.51.0 で確認）。secret は `sbx env rm` で sandbox と一緒に消えるので、作り直したら登録し直す。

エージェントは無人で動き、自分の環境変数はすべて読める。環境変数の読み取りはコマンド実行を伴わないため承認機構では止められない。credential 注入なら実値はホストにしか無く、VM が侵害されても値は漏れない（許可ドメインへの悪用のみ）。失効は secret の差し替え + 発行元での revoke で行う。

環境変数として実値が要るツールが出てきた場合は、値が VM に入るトレードオフを理解したうえで個別に判断する。

### トークンを画面・履歴に残さず登録する

`-t/--token` は CLI リファレンス自身が "less secure: visible in shell history" と注記しているので使わない。代わりに:

- **対話入力（既定）** — `-t` を省くと値の入力を求められ、コマンドラインにも履歴にも残らない
- **`--ref "op://<vault>/<item>/<field>"`** — 1Password 参照と AWS Secrets Manager の ARN に対応（対応 CLI がホストに認証済みであること）
- **`--command '<値を stdout に出すコマンド>'`** — `--ref` 非対応のパスワードマネージャ（Proton Pass の pass-cli 等）はこちら。`--command 'gh auth token'` も動くがユーザー全体のトークンなので方針から外れる

`--ref` / `--command` は値そのものではなく取得元を保存し、`--refresh`（既定 55m）でキャッシュするため、失効時の差し替えが発行元だけで済む。`--show-error` はエラー出力にシークレットが混じり得るので常用しない。やむを得ず `-t` を使う場合もコマンド置換にする（実行中は `ps` に見える点は残る）。対話プロンプトの有無は CLI バージョン依存なので、出ない場合は `--ref` / `--command` を使う。

## Chrome DevTools MCP

VM 内の headless Chromium で画面を確認できる。sandbox 内での確認:

```bash
claude mcp list                      # chrome-devtools が出ること
/usr/local/bin/chromium-no-sandbox --version
```

Codex は kit が seed する `~/.codex/config.toml` の `[mcp_servers.chrome-devtools]` で同じものを参照する。

## オーケストレーション（1 sandbox に複数エージェント）

sandbox はエージェント kit 単位だが、共有 kit が委譲先 CLI を同居させるため、claude sandbox は Claude Code を親にしたオーケストレーション環境として使える。

- kit が Codex CLI / OpenCode CLI を入れ、Codex を Claude Code のプラグイン（`codex-rescue` + `/codex`）として登録する（codex sandbox では `command -v` ガードで no-op）。組み込み opencode kit は本 kit と組み合わせられないため、OpenCode はこの経路で使う
- Codex 設定 seed も共通なので、委譲実行が承認待ちで止まらない
- 委譲先の認証は、sandbox 内での対話ログイン（削除まで永続）か、プロキシ注入（`sbx secret set openai --sandbox <sandbox名>`）。サブスクリプション認証なら対話ログイン一択

**sandbox をまたいだ協調は基本できない**（FS もネットワークも隔離、clone モードでは各自が独立クローンを持つ）。受け渡しは GitHub 経由になるため、密結合のオーケストレーションは 1 つの sandbox に同居させる。

## トラブルシューティング（認証まわり）

`gh auth status` に相当する専用コマンドは無い。実用上は **`sbx ls` が認証プローブ**になる（認証が生きていれば一覧、壊れていれば認証エラー）。

「cannot prompt the user for password」「store is locked」等が `sbx login` でも解消しない場合、`sandboxd` が認証ストアのロックを握っている可能性がある。復旧（macOS）:

```bash
pkill sandboxd
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/
sbx ls && sbx login
```

sandbox 本体のデータ（`com.docker.sandboxes` 側）は消さないこと。

**SSH / headless セッションの制約:** sbx は認証情報を OS のキーチェーンに保存するため、施錠されたままの SSH / headless では `sbx login` が失敗する（[#180](https://github.com/docker/sbx-releases/issues/180) / [#186](https://github.com/docker/sbx-releases/issues/186)）。macOS へ SSH しているなら同じシェルで `security unlock-keychain ~/Library/Keychains/login.keychain-db`、駄目なら一度 GUI セッションで `sbx login` を済ませる。headless Linux なら session D-Bus + `gnome-keyring-daemon --components=secrets` を起動し `DBUS_SESSION_BUS_ADDRESS` を継承させる。認証まわりは修正が活発なので、まず最新化して試す。
