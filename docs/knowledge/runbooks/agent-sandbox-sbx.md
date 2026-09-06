---
type: Runbook
title: AI エージェント Sandbox（Docker Sandboxes / sbx）
description: sbx で microVM 隔離のエージェント実行環境を運用する手順
tags: [sandbox, agents, security]
timestamp: 2026-09-05T00:00:00Z
---

# AI エージェント Sandbox（Docker Sandboxes / sbx）

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）で AI エージェントを microVM 内で実行する構成。kit は `.sandbox/` にある。[Dev Container](/docs/knowledge/runbooks/devcontainer.md) と併存し、人間の対話的開発は devcontainer、エージェントの無人実行や強い隔離が要るタスクは sbx、という使い分け。

devcontainer に対する追加の保証:

- **microVM 境界** — 独立カーネル。コンテナエスケープにつながる脆弱性も封じ込める
- **deny-by-default のネットワーク** — 外向き TCP は許可リストのドメインのみ（UDP / ICMP は遮断）
- **credential 非搬入** — トークンはホスト側プロキシが HTTP ヘッダに注入し、実値が VM に入らない
- **sandbox ごとの Docker デーモン** — ホストの Docker に触れない

検証状況と未確認事項は [sbx 実機検証](/docs/knowledge/research/sbx-verification.md) を参照。

> `sbx` は**ホスト OS 上で実行する**。devcontainer の中からは使えない。

## 前提とインストール

macOS 14+ / Apple Silicon、Windows 11、Ubuntu 24.04+（KVM 有効）。Docker Desktop / Engine は不要（既存の Colima 等とも共存可）。

```bash
brew install docker/tap/sbx   # macOS。他 OS は公式ドキュメント参照
sbx version
sbx login                     # 必須。未サインインだと各コマンドが認証エラーで失敗する
```

初回にデフォルトのネットワークポリシー選択を求められることがある。kit が必要ドメインを allow で足すので **Locked Down か Balanced** を選ぶ。

## 初回セットアップ

組み込みエージェントの既定起動コマンドは YOLO なので上書きする（後述）。以下はサブスクリプション認証（Claude Max / ChatGPT）をそのまま使う**方式 A**。

```bash
cd <このリポジトリの checkout>

# 1) sandbox だけ作る（エージェントは起動しない）。位置引数は組み込みの agent type。
#    --clone は必須（後述）。作成時の credentials 利用確認は Approve する。
sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit claude .

# 2) 望みの権限モードで起動する（毎回この形で入る。sbx run だと YOLO entrypoint が起動する）
sbx exec -it -w "$PWD" claude-auto-<ディレクトリ名> claude --permission-mode auto

# 3) GitHub の fine-grained PAT をその sandbox にスコープして登録（値は対話入力）
sbx secret set github --sandbox claude-auto-<ディレクトリ名>

# Codex も同様。OpenCode は暗黙のフラグが無いので素の sbx run でよい。
sbx create --name codex-approve-<ディレクトリ名> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<ディレクトリ名> codex --approve-for-me
sbx run opencode --clone --kit ./.sandbox/kit
```

`--name` を省くと sandbox 名は `<agent>-<ディレクトリ名>` になる（`sbx ls` か VM 内の `$SANDBOX_NAME` で確認）。並行作業したいときだけ明示的に名前を付ける。初回はエージェントごとの認証（ブラウザログイン等）が必要で、VM 内の状態は `sbx rm` まで永続する。

> **`-g`（グローバル）は使わない。** グローバル登録は他リポジトリの sandbox にも注入され得るため、「リポジトリごとに権限を区切る」方針に反する。`sbx secret set` の引数形式は CLI バージョンで異なるので、差異が出たら `sbx secret set --help` を見る。

kit（`.sandbox/kit/spec.yaml`）が作成時にセットアップするもの: Node 24 + corepack + pnpm、headless Chromium + 日本語フォント + `chromium-no-sandbox` ラッパー、`chrome-devtools-mcp` の登録、Codex 設定 seed（既存があれば上書きしない）、委譲先 CLI（Codex / OpenCode）と Claude Code への Codex プラグイン登録、ネットワーク許可リストと GitHub PAT のヘッダ注入設定。

## YOLO 既定の上書き

組み込みエージェントの既定は `claude --dangerously-skip-permissions` / `codex --dangerously-bypass-approvals-and-sandbox`（`opencode` は暗黙のフラグ無し）。本テンプレートでは `claude --permission-mode auto`（判断はモデルに委ねるが bypass はしない）/ `codex --approve-for-me`（workspace-write を保ち、承認要求を自動レビューへ回す）に差し替える。

**`--` によるパススルーでは上書きできない** — 先頭がフラグの引数は既定フラグの後ろに追加されるだけで、bypass フラグは残る。手段は 2 つあり、認証方式で選ぶ。

### 方式 A: `sbx create` + `sbx exec`（サブスクリプション認証）

上記「初回セットアップ」の手順。`sbx create` は sandbox を作るだけでエージェントを起動しないため YOLO entrypoint を踏まず、agent type も組み込みのままでいられる。credential 注入はホスト側プロキシが通信を intercept する仕組みなので、`sbx exec` した別プロセスでも境界は保たれる（実測: `~/.claude/.credentials.json` のトークンは sentinel 長で、実値は VM に無い）。

注意: **再接続も必ず `sbx exec` で行う**（`sbx run` で入ると既定の YOLO entrypoint が起動する）。

### 方式 B: fork kit（API キー課金にできる場合）

`sandbox.entrypoint` / `sandbox.command` は `kind: sandbox` の kit にしか書けない（mixin kit は `sandbox:` ブロックを持てない）ため、組み込みエージェントを `extends` する薄い fork kit を用意してある（`.sandbox/claude-auto/`、`.sandbox/codex-approve/`）。

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

fork kit は起動コマンド以外を親から継承する。`entrypoint` と `command` の**両方**を明示宣言しているのは、親の bypass フラグがどちらに入っているか公開されておらず、片方だけ差し替えると気付かないまま YOLO のまま残る（沈黙する失敗）ため。

> **認証の制約:** `extends` した kit ではプロキシ管理の OAuth が使えない。起動前にホストで API キーを登録する（`sbx secret set anthropic` / `openai`）。VM 内で `/login` すると実トークンが VM に保存され、方針から外れる。サブスクリプション課金のままなら方式 A を使う。

### 設定ファイルとの関係

`.claude/settings.json` と Codex の `config.toml` seed も同じ方針に揃えてあるが、**起動時フラグの方が強い**。さらに sbx は VM 内の `~/.claude/settings.json` に `"defaultMode": "bypassPermissions"` を仕込んでいる（実測）ので、リポジトリ側の設定が優先されることを期待せず、常にフラグで明示する。

## 日常運用

- 同じワークスペースで `sbx run` すると既存 sandbox に再接続する（install は再実行されない）
- `sbx ls` で一覧、`sbx stop <name>` で停止、`sbx rm <name>` で削除（**VM 内の全状態が消える** — push していないコミットも失われる）
- kit を更新したら `sbx rm` → 作り直しで反映する（`sbx kit add` は `setup.files` を含む kit を受け付けない）

## clone モードで運用する

`sbx run` の既定は direct モード（ホストの FS をパススルー）だが、**このテンプレートでは `--clone` を必ず付ける**。direct モードには両立しない問題がある:

1. `node_modules` がホストと共有され、macOS バイナリと Linux バイナリが衝突する。sandbox 側の `pnpm install` がホストの `node_modules` を上書きするため運用ルールでは防げず、`.pre-commit-config.yaml` の `language: system` hooks がホストの darwin バイナリを要求することと両立しない。既存 `node_modules` があると `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` で止まりもする
2. virtiofs が symlink の `st_size` を 0 と報告する。`CLAUDE.md`（→ `AGENTS.md`）のようなリンクが「中身が消えた」差分に出て、気付かずコミットすると壊れたファイルが記録される
3. `node_modules` の I/O が virtiofs 越しで遅い

clone モードではワークスペースが VM 内の独立した git クローン（worktree ではない）になるため、いずれも起きない。

運用上の違い:

- **未コミットの変更と gitignore されたファイルはクローンに入らない。** 作業中の変更があるなら先にコミットする
- **成果は push で受け取る。** `git push`（https）はプロキシのヘッダ注入で通るので、ブランチを push して PR にするのが基本経路
- push せずホストへ取り出すなら、sandbox が公開する git-daemon から取る（起動中のみ有効）: `git fetch sandbox-<sandbox名>`
- 逆に sandbox 作成後にホストへ積んだコミットを取り込むには、read-only bind mount されたホストリポジトリから取る（`origin` は GitHub を指すのでホストの未 push コミットは含まれない）: `git fetch /run/sandbox/source`
- **`sbx rm` は push していないコミットを消す。** 長時間の無人実行ではこまめに push させる

## ホストの別フォルダを参照させる

`sbx create` / `sbx run` の位置引数にパスを足す。最初のパスが primary workspace、2 つ目以降が追加マウント。

```bash
sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit \
  claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

- 追加ワークスペースは `--clone` の対象外で常に direct mount。VM 内ではホストの絶対パスのまま見える
- **参照目的なら必ず `:ro` を付ける** — direct mount なので上記の direct モードの問題がそのまま当てはまる（書き込みがホストへ即反映される / symlink を壊したコミットが生まれ得る）。`node_modules` を含むフォルダは渡さない
- ワークスペースの追加は作成時のみ。あとから足すには作り直し

他の受け渡し手段: 単発ファイルは `sbx cp ./config.json <sandbox名>:/home/agent/`（逆方向も可）、このリポジトリの最新コミットは `/run/sandbox/source`、VM 内の作業領域だけなら kit の `volumes:`（ホストの bind mount ではない）。

## sbx が自動で継承するもの

devcontainer の `initialize.sh` に相当する処理の一部は sbx 側が組み込みで行う（claude テンプレートで実測）:

- git identity（`user.name` / `user.email`）はホストの値が入る
- グローバル gitignore は `/home/agent/.gitignore_global` に配置される
- `~/.claude/skills` はホストから **rw の virtiofs bind mount** — エージェントが書き換えるとホスト側にも反映される

継承されない（VM 内で新規に作られる）もの: `~/.claude/settings.json`、`statusline-command.sh`、`~/.claude.json`。リポジトリの `.claude/settings.json` は clone で入るが `settings.local.json` は入らない。

ホスト固有の Claude Code 設定を持ち込む手段は 3 つ。チームで共有したいものは kit の `setup.files`（リポジトリにコミットされる）、個人設定は `sbx cp`（作り直すたびに再実行）、参照させたいだけのファイル群は追加ワークスペース `<path>:ro`（**`~/.claude` を丸ごと渡さないこと** — `.credentials.json` にホストの実トークンが含まれる）。

```bash
sbx cp ~/.claude/statusline-command.sh <sandbox名>:/home/agent/.claude/statusline-command.sh
```

`settings.json` を丸ごと上書きしないこと（VM 側の `apiKeyHelper` などプロキシ管理の認証キーが消える）。必要なキーだけ追記し、ホームのパスは `/home/agent` に書き換える。

## ネットワークポリシーの監査

外向き通信は deny-by-default だが、**デフォルトの許可リストには広い wildcard が含まれる**。初回に `sbx policy ls` で確認すること。kit の `permissions.network.allow` はデフォルトへの追加であり、広い許可を削るものではない（絞るのはホスト側の `sbx policy` 操作。deny は allow より優先される）。

VM 内からのプローブでは、**HTTP ステータスではなく本文で判別する**。許可済みドメインでも 4xx は普通に返る（`claude.ai` は Cloudflare のボットチャレンジで 403、`api.anthropic.com` は GET `/` に 404）。拒否は本文が `Blocked by network policy` で始まる。

```bash
curl -s https://example.com/ | head -1
# Blocked by network policy: domain example.com:443
#   detail: no matching allow rule — blocked by default deny policy
```

デフォルトポリシーは `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していないため、kit の allow に追加してある。テレメトリ系（`sentry.io` 等）は拒否のままが望ましい。

## タスク用シークレット

devcontainer の pass-cli 方式は持ち込まず、sbx のネイティブ機構を使う。

```bash
sbx secret set example --sandbox <sandbox名>   # 名前は kit の credentials の service 名に合わせる
```

kit の `credentials` にエントリを追加すると（spec.yaml にコメントアウトの雛形あり）、指定ドメイン宛のリクエストにのみホスト側プロキシがヘッダを注入する。VM 内の環境変数には sentinel 値が入る。kit の変更反映には作り直しが要るが、sandbox-scoped の secret は実行中でも即時反映される。

pass-cli 方式との違い:

| | pass-cli（devcontainer） | sbx credential 注入 |
|---|---|---|
| 値の所在 | コンテナ内（PAT ファイル + セッション） | ホストのみ。VM に実値が入らない |
| 注入単位 | コマンド単位の環境変数 | ドメイン限定の HTTP ヘッダ |
| 侵害時 | コンテナ侵害 = PAT 侵害（vault スコープで限定） | VM 侵害でも値は漏れない（許可ドメインへの悪用のみ） |
| 失効運用 | Proton 側で revoke | secret の差し替え + 発行元で revoke |
| スコープ | プロジェクト別 vault | sandbox 単位 |

環境変数として実値が要るツールが出てきた場合は、値が VM に入るトレードオフを理解したうえで個別に判断する。

### トークンを画面・履歴に残さず登録する

`-t/--token` は CLI リファレンス自身が "less secure: visible in shell history" と注記しているので使わない。代わりに:

- **対話入力（既定）** — `-t` を省くと値の入力を求められ、コマンドラインにも履歴にも残らない
- **`--ref "op://<vault>/<item>/<field>"`** — 1Password 参照と AWS Secrets Manager の ARN に対応（対応 CLI がホストに認証済みであること）
- **`--command '<値を stdout に出すコマンド>'`** — `--ref` 非対応のパスワードマネージャ（Proton Pass の pass-cli 等）はこちら。`--command 'gh auth token'` も動くがユーザー全体のトークンなので方針から外れる

`--ref` / `--command` は値そのものではなく取得元を保存し、`--refresh`（既定 55m）でキャッシュするため、失効時の差し替えが発行元だけで済む。`--show-error` はエラー出力にシークレットが混じり得るので常用しない。やむを得ず `-t` を使う場合もコマンド置換にする（実行中は `ps` に見える点は残る）。対話プロンプトの有無は CLI バージョン依存なので、出ない場合は `--ref` / `--command` を使う。

## Chrome DevTools MCP

devcontainer と同様、VM 内の headless Chromium で画面を確認できる。sandbox 内での確認:

```bash
claude mcp list                      # chrome-devtools が出ること
/usr/local/bin/chromium-no-sandbox --version
```

Codex は kit が seed する `~/.codex/config.toml` の `[mcp_servers.chrome-devtools]` で同じものを参照する。

## オーケストレーション（1 sandbox に複数エージェント）

sandbox はテンプレートイメージ単位だが、kit が委譲先 CLI を同居させるため、claude sandbox は Claude Code を親にしたオーケストレーション環境として使える。

- kit が Codex CLI / OpenCode CLI を入れ、Codex を Claude Code のプラグイン（`codex-rescue` + `/codex`）として登録する（devcontainer の `post-create.sh` と同じ構成。単体実行用 sandbox では `command -v` ガードで no-op）
- Codex 設定 seed も共通なので、委譲実行が承認待ちで止まらない
- 委譲先の認証は、sandbox 内での対話ログイン（`sbx rm` まで永続）か、プロキシ注入（`sbx secret set openai --sandbox <sandbox名>`）。サブスクリプション認証なら対話ログイン一択

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
