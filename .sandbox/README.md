# AI Agent Sandbox（Docker Sandboxes / sbx）

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）で AI コーディングエージェントを microVM 内で実行するための構成です。現行の [Dev Container](../.devcontainer/README.md) と**併存**します — devcontainer を置き換えるものではなく、まず並行運用して問題なければ devcontainer 側のエージェント関連を縮退させる、という段階移行を想定しています。

## 位置づけ

devcontainer は Linux コンテナを隔離境界としており、`.devcontainer/README.md` の「この隔離が担保しない範囲」に記載の通り、独立カーネル・細粒度のネットワーク allow/deny・ネスト Docker は提供しません。同節が推奨する「より保証の強いサンドボックス」を実装するのがこのディレクトリです。sbx で得られる追加の保証:

- **microVM 境界** — 独立カーネル。コンテナエスケープにつながるカーネル脆弱性も封じ込める
- **deny-by-default のネットワーク** — 外向き TCP はドメイン許可リストに載ったものだけ通る（UDP / ICMP は遮断）
- **credential 非搬入** — API キーやトークンはホスト側プロキシが HTTP ヘッダに注入し、**実値が VM に入らない**
- **sandbox ごとの独立した Docker デーモン** — エージェントがコンテナをビルド・実行してもホストの Docker に触れない

使い分けの目安:

| 用途 | 環境 |
|---|---|
| 人間の対話的開発、VS Code での作業 | Dev Container |
| エージェントの無人実行、強い隔離が必要なタスク | sbx |

> **注意:** `sbx` は**ホスト OS 上で実行するもの**です。devcontainer の中からは使えません。

## 前提とインストール

- macOS 14 (Sonoma) 以降 + Apple Silicon、Windows 11、または Ubuntu 24.04+（KVM 有効）
- Docker Desktop / Docker Engine は**不要**（`sbx` はスタンドアロンの microVM ランタイム。Colima 等の既存 Docker 環境とも共存可）

```bash
brew install docker/tap/sbx   # macOS の場合。他 OS は公式ドキュメント参照
sbx version

# Docker アカウントへのサインイン（必須。ブラウザのデバイスコードフローが開く）。
# 未サインインだと sbx の各コマンドが
# 「unexpected authentication error: ... cannot prompt the user for password」
# で失敗する。Colima 等の docker login とは別物で、sbx 自身の認証が必要。
sbx login
```

サインイン後、初回にデフォルトのネットワークポリシー（Open / Balanced / Locked Down）の選択を求められることがあります。本テンプレートの方針では **Locked Down か Balanced** を推奨します（kit が必要ドメインを `allow` で追加するため。後から `sbx policy` で調整可能）。

## 初回セットアップ

組み込みエージェントの既定起動コマンドは YOLO なので、本テンプレートではそれを上書きします。手順は認証方式で変わります（後述「YOLO 既定の上書き」）— 以下は**サブスクリプション認証（Claude Max / ChatGPT）をそのまま使う方式 A** の手順です。API キー課金にできるなら方式 B（fork kit）の方が手順は短くなります。

```bash
# 1) リポジトリの checkout ディレクトリで、共有 mixin を適用して sandbox だけ作る。
#    位置引数は組み込みの agent type（claude）。エージェントはまだ起動しない。
#    --name を付けないと sandbox 名は `<agent>-<ディレクトリ名>` になる。
#    作成時に kit の credentials 利用確認が出るので Approve する
#    （ここで No にするとプロキシ注入が効かない）。
#    --clone は必須（理由は後述「clone モードで運用する」）。
cd <このリポジトリの checkout>
sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit claude .

# 2) 望みの権限モードで起動する（毎回この形で入る。`sbx run` で入ると既定の
#    YOLO entrypoint が起動してしまう点に注意）
sbx exec -it -w "$PWD" claude-auto-<ディレクトリ名> claude --permission-mode auto

# 3) GitHub の fine-grained PAT を、その sandbox だけにスコープして登録。
#    -t は付けない — 値は対話プロンプトで入力する（コマンドラインにも
#    シェル履歴にも残さないため。CLI リファレンス自身が -t を
#    "less secure: visible in shell history" と注記している）。
#    パスワードマネージャから引く方法は「タスク用シークレット」の
#    「トークンを画面・履歴に残さず登録する」を参照。
#    （`github` は kit の credentials の service 名と対応する。`--sandbox` には
#      sandbox 名を渡す（`sbx ls` で確認できる）。
#      sandbox-scoped の secret は実行中の sandbox にも即時反映される。
#      スコープ方針は .devcontainer/README.md「GitHub 権限の制限（PAT）」と同じ —
#      リポジトリ単位のスコープ限定 PAT を、そのリポジトリの sandbox にだけ渡す。
#      値は VM に入らず、プロキシが GitHub 宛リクエストのヘッダにのみ注入する）
sbx secret set github --sandbox claude-auto-<ディレクトリ名>

# Codex も同様。OpenCode は既定で暗黙のフラグが無いため、素の `sbx run` でよい。
sbx create --name codex-approve-<ディレクトリ名> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<ディレクトリ名> codex --approve-for-me
sbx run opencode --clone --kit ./.sandbox/kit
```

同一ワークスペース・同一エージェントで複数の sandbox を並行させたい場合のみ `--name` で明示的に名前を付けます。

> **`-g`（グローバル）は使わない:** `sbx secret set -g github` はユーザー全体のグローバル登録で、**以後作成するすべての sandbox（他リポジトリ含む）に注入され得ます**。`github` のような組み込みサービスは kit の宣言が無くても provenance で自動注入されるため、グローバル登録は「リポジトリごとに権限を区切る」本テンプレートの方針に反します。sandbox 名スコープで登録してください（グローバル値があっても sandbox-scoped が優先されます）。なお `sbx secret set` の引数形式は CLI バージョンで異なります。本 README は現行の `sbx secret set <service> --sandbox <sandbox名>` 形式で記載しています（旧 CLI の `sbx secret set <sandbox名> <service>` 形式で動く環境もあります）— 差異が出たら `sbx secret set --help` で確認してください。

初回はエージェントごとの認証（Claude はブラウザログイン等）が必要です。認証を含む sandbox 内の状態は `sbx rm` するまで永続します。

kit（[kit/spec.yaml](kit/spec.yaml)）が sandbox 作成時にセットアップする内容:

- Node 24 + corepack + pnpm（`package.json` の `packageManager` と同じバージョン）
- headless Chromium + 日本語フォント + `/usr/local/bin/chromium-no-sandbox` ラッパー（devcontainer と同一パス。Chromium 本体は Debian 系なら apt、Ubuntu 系テンプレートでは apt の chromium が snap 移行パッケージのため Playwright 配布の linux-arm64 ビルドを使用）
- `chrome-devtools-mcp` のグローバルインストールと Claude Code への登録
- Codex の初期設定 seed（`~/.codex/config.toml`。既存があれば上書きしない）
- 委譲先 CLI（Codex / OpenCode）の導入と、Claude Code への Codex プラグイン登録（下記「オーケストレーション」参照。テンプレート同梱済み・claude 不在の sandbox では no-op）
- ネットワーク許可リストの追加と GitHub PAT のヘッダ注入設定

## YOLO 既定の上書き

sbx の組み込みエージェントは**既定の起動コマンドが YOLO**です:

| エージェント | sbx の既定起動コマンド |
|---|---|
| `claude` | `claude --dangerously-skip-permissions` |
| `codex` | `codex --dangerously-bypass-approvals-and-sandbox` |
| `opencode` | `opencode`（暗黙のフラグ無し） |

microVM が隔離境界とはいえ、ワークスペースの破壊やネットワーク越しの操作まで無制限にする理由は無いため、本テンプレートでは既定を次に差し替えます:

| エージェント | 差し替え後 | 意味 |
|---|---|---|
| `claude-auto` | `claude --permission-mode auto` | 権限判断はモデルに委ねるが bypass はしない |
| `codex-approve` | `codex --approve-for-me` | workspace-write を保ち、エスカレーションされた承認要求を自動レビューへ回す |

**`--` によるパススルーでは上書きできません。** `sbx run claude -- --permission-mode auto` のように渡した引数は、先頭がフラグの場合**既定フラグの後ろに追加される**だけで、`--dangerously-skip-permissions` は残ります。差し替える手段は 2 つあり、**認証方式で選び分けます**。

### 方式 A: `sbx create` + `sbx exec`（サブスクリプション認証を使う場合）

sandbox の作成とエージェントの起動を分けます。`sbx create` は sandbox を作るだけでエージェントを起動しないため、既定の YOLO entrypoint を踏まずに済み、agent type は**組み込みの `claude` / `codex` のまま**でいられます:

```bash
# 1) 組み込み agent type で sandbox だけ作る（kit は共有 mixin のみ）
sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit claude .

# 2) 望みのフラグで直接起動する（-w にはワークスペースのパス。
#    clone モードでもホストの絶対パスがミラーされるので $PWD でよい）
sbx exec -it -w "$PWD" claude-auto-<ディレクトリ名> claude --permission-mode auto
```

```bash
sbx create --name codex-approve-<ディレクトリ名> --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-approve-<ディレクトリ名> codex --approve-for-me
```

**この方式の利点は、組み込みエージェントのプロキシ管理 OAuth をそのまま使えることです。** credential 注入は「最初に起動したプロセス」に紐づくのではなく、sandbox から出る通信をホスト側プロキシが intercept して行う仕組みなので、同じ sandbox 内で `sbx exec` した別プロセスでも境界は保たれます。実際にこの sandbox の `~/.claude/.credentials.json` を調べると、`claudeAiOauth.accessToken` / `refreshToken` はいずれも 26 文字と `GH_TOKEN`（13 文字）と同種の **sentinel 長**で、実トークンは VM に入っていません。

注意点:

- **`sbx run` で再接続すると既定の YOLO entrypoint が起動します。** 以後も常に `sbx exec` 側の手順で入ってください
- **`--name` を省くと sandbox 名は `claude-<ディレクトリ名>`**（`claude-auto-` の前置きは付きません）。本節のコマンド例は `--name` を明示した前提なので、省いた場合は `sbx secret set --sandbox` / `git fetch sandbox-...` に渡す名前を実名（`sbx ls`、または VM 内の `$SANDBOX_NAME`）へ読み替えてください
- **この組み合わせは公式ドキュメントに完成形の recipe として載っていません。** `sbx create` / `sbx exec` 自体は正式なコマンドですが、「組み込み sandbox を作って同じ agent binary を別フラグで exec し、OAuth も使う」構成は本テンプレートでの推論です。**claude テンプレート + Claude Max サブスクリプションでは実機検証済み**（「既知の未確認事項」参照）。codex テンプレート + ChatGPT サブスクリプションは未確認です

### 方式 B: fork kit（API キー課金にできる場合）

`sandbox.entrypoint` / `sandbox.command` は `kind: sandbox` の kit にしか書けません（mixin kit は `sandbox:` ブロックを持てない）。そのため共有 mixin（[kit/spec.yaml](kit/spec.yaml)）とは別に、組み込みエージェントを `extends` するだけの薄い fork kit を用意しています:

- [claude-auto/spec.yaml](claude-auto/spec.yaml) — `extends: claude`
- [codex-approve/spec.yaml](codex-approve/spec.yaml) — `extends: codex`

`--kit` は複数回指定でき、`sbx run` の位置引数は fork kit の `name:` を渡します:

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

fork kit は image・credentials・ネットワーク許可・volume・MCP 連携・エージェント指示を親から継承し、上書きするのは起動コマンドだけです。その際 **`entrypoint` と `command` の両方を明示的に宣言**しています — 実効コマンドは `entrypoint` + `command`（TTY では `command.interactive`、非対話では `command.default`）で、親の bypass フラグがどちらに入っているかは公開されていないためです。`entrypoint` だけを差し替えると、親のフラグが `command` 側にあった場合に `claude --permission-mode auto --dangerously-skip-permissions` となり、**気付かないまま YOLO のまま**になります（沈黙する失敗）。両方を宣言すれば継承がゼロになり、どちらの構造でも安全側に倒れます。

> **認証の制約:** 組み込みエージェントを `extends` した kit では**プロキシ管理の OAuth が使えません**。初回起動前にホストで API キーを登録してください（`sbx secret set anthropic` / `sbx secret set openai`）。VM 内で `/login`（OAuth）を使うと、**実トークンが VM 内に保存されます** — 「実値を VM に入れない」という本テンプレートの方針から外れます。サブスクリプション課金のまま使いたい場合は方式 A を選んでください。

### 設定ファイル側との関係

Claude Code の `.claude/settings.json`（`permissions.defaultMode: "auto"`）と Codex の `~/.codex/config.toml` seed（`approval_policy = "on-request"` / `approvals_reviewer = "auto_review"`）も同じ方針に揃えてありますが、**起動時フラグの方が強い**ため、sbx では方式 A / B が実効値を決めます。設定ファイル側は、devcontainer やホストでの実行、および Claude から Codex へ委譲したときのように起動コマンドを経由しない場合に効きます。

## 日常運用

- 同じワークスペースで `sbx run` すると**既存 sandbox に再接続**します（install は再実行されない）
- `sbx ls` で一覧、`sbx stop <name>` で停止、`sbx rm <name>` で削除（**VM 内の全状態が消える** — clone モードでは push していないコミットも失われる）
- kit を更新したら `sbx rm` → 再 `sbx run --clone --kit ...` で作り直して反映する（`sbx kit add` は `setup.files` を含む kit を受け付けないため、この kit には使えない）
- 同一ワークスペースで並行作業したい場合は `--name` で別名の sandbox を作る

## clone モードで運用する

`sbx run` は既定では **direct モード**（ホストのファイルシステムをパススルーし、VM 内でもホストの絶対パス `/Users/...` のまま見える）ですが、**このテンプレートでは `--clone` を必ず付けてください**。direct モードには本テンプレート構成と両立しない問題があります:

1. **`node_modules` がホストと共有され、macOS バイナリと Linux バイナリが衝突する。** 「ホスト側で `pnpm install` しない」という運用ルールでは防げません — sandbox 側の `pnpm install` が**ホストの `node_modules` を Linux 版で上書きしてしまう**からです。`.pre-commit-config.yaml` の hooks は `language: system` でホストの `pnpm biome` / `pnpm typecheck` を叩くため、ホストでコミットする限り darwin バイナリの `node_modules` が必要で、両立しません。加えて、ホストに既存の `node_modules` があると sandbox 内の `pnpm install` が purge 確認を求め、TTY が無いため `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` で止まります
2. **virtiofs がシンボリックリンクの `st_size` を 0 と報告する。** git は symlink をサイズ経由で読むため、`CLAUDE.md`（→ `AGENTS.md`）のようなリンクが「中身が消えた」変更として差分に出ます。**気付かずコミットすると、リンク先が空の壊れたファイルが記録されます**
3. `node_modules` の I/O が virtiofs 越しになり、インストール・テストが遅い

clone モードではワークスペースが **VM 内の独立した git クローン**（worktree ではない）になるため、いずれも構造的に起きません。ホストの `node_modules` はそのまま温存でき、触る必要がありません。

### 運用上の違い

- **未コミットの変更はクローンに入りません。** 作業中の変更がある状態で sandbox を作り直す場合は、先にコミットしてください
- **gitignore されたファイルも入りません。** 実害があるとすれば `.claude/settings.local.json`（Claude Code の権限許可リスト）が無く許可プロンプトが復活する程度で、`.devcontainer/host-*` は devcontainer 専用のため sbx には無関係です
- **成果は push で受け取ります。** GitHub への `git push` はプロキシのヘッダ注入で通ることを確認済みなので、ブランチを push して PR にするのが基本の受け渡し経路です。「エージェントの無人実行 → PR でレビュー」という本テンプレートの使い分けとも噛み合います
- push せずにホストへ取り出したい場合は、ホスト側で sandbox が公開する git-daemon から取得します（sandbox 起動中のみ有効）:

  ```bash
  git fetch sandbox-claude-auto-<ディレクトリ名>
  ```

- 逆に、**sandbox 作成後にホストへ積んだコミット**を VM 内へ取り込むには、read-only で bind mount されたホストリポジトリから fetch します（`origin` は GitHub を指すため、ホストの未 push コミットは含まれません）:

  ```bash
  git fetch /run/sandbox/source
  git log HEAD..FETCH_HEAD --oneline
  ```

- **`sbx rm` は push していないコミットを消します。** 長時間の無人実行ではこまめに push させてください（kit の `agentInstructions` にも明記しています）

## ホストの別フォルダを参照させる

devcontainer で bind mount（`compose.yaml` の `volumes`）や `initialize.sh` のステージングでやっていたことに相当します。sbx では **`sbx create` / `sbx run` の位置引数にパスを追加**します — 最初のパスが primary workspace で、2 つ目以降が追加マウントです:

```bash
sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit \
  claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

- 追加ワークスペースは **`--clone` の対象外で、常に direct mount** されます（clone されるのは最初のパスだけ）
- VM 内では**ホストの絶対パスのまま**見えます（`~/develop/other-repo` → `/Users/<user>/develop/other-repo`）
- `:ro` を付けると読み取り専用。`sbx run` でも同じ書き方ができます
- **ワークスペースの追加は作成時のみです。** あとから足すには `sbx rm` → 作り直し（kit の更新と同じ）

> **参照目的なら必ず `:ro` を付けてください。** 追加分は direct mount なので、「clone モードで運用する」に挙げた direct モードの問題がそのまま当てはまります — `:ro` 無しだとエージェントの書き込みがホストへ即反映されて隔離がそこだけ穴になり、virtiofs の symlink `st_size` = 0 問題があるため git リポジトリを rw で渡すとリンクを壊したコミットが生まれ得ます。`node_modules` を含むフォルダは macOS / Linux バイナリの混在を招くので渡さないこと。

用途別の使い分け:

| やりたいこと | 手段 |
|---|---|
| ホストの別フォルダを参照させる | 追加ワークスペース `<path>:ro` |
| 単発のファイルを渡す / 取り出す | `sbx cp ./config.json <sandbox名>:/home/agent/`（逆方向も可。片側は `SANDBOX:PATH` 形式） |
| ホストの**このリポジトリ**の最新コミット | `/run/sandbox/source`（read-only bind mount。「運用上の違い」参照） |
| VM 内の作業領域が欲しいだけ | kit の `volumes:`（**ホストの bind mount ではない** — VM 内の block / tmpfs ボリューム） |

### sbx が自動で継承するもの

devcontainer の `initialize.sh` に相当する処理の一部は sbx 側が組み込みで行っています。claude テンプレートの VM 内で実測した内容:

- **git identity** — `user.name` / `user.email` はホストの値が入っている（ステージング不要）
- **グローバル gitignore** — `core.excludesFile` = `/home/agent/.gitignore_global` として配置済み
- **`~/.claude/skills`** — ホストから **rw の virtiofs bind mount**（`mount | grep virtiofs` で確認できる）。つまりホストのスキル群が共有され、**エージェントが書き換えるとホスト側にも反映される**
- 一方、ホストの `~/.claude/settings.json` は継承されません（VM 内には sbx 用の別内容が置かれる）。statusline のようなホスト固有設定が要る場合は kit の `setup.files` で書くか `sbx cp` で運ぶ

## ネットワークポリシーの監査

外向き通信は deny-by-default ですが、**デフォルトの許可リストには広い wildcard が含まれます**。初回に必ず確認してください:

```bash
sbx policy ls
```

kit の `permissions.network.allow` は**デフォルトポリシーへの追加**であり、デフォルト側の広い許可を削るものではありません。実効ポリシーを絞るのはホスト側の `sbx policy` 操作で行います（deny は allow より優先されるため、kit に `permissions.network.deny` を足して特定ドメインを塞ぐこともできます）。kit の allow（npm registry / 各エージェントの API / GitHub / apt リポジトリ）だけで回る状態が理想です。

VM 内から実際にプローブすると、許可されているかどうかは応答の中身で判別できます（拒否は HTTP 403 + `Blocked by network policy` 本文）:

```bash
curl -s https://example.com/ | head -1
# Blocked by network policy: domain example.com:443
#   detail: no matching allow rule — blocked by default deny policy
```

**HTTP ステータスだけで判断しないでください。** 許可されているドメインでも 4xx は普通に返ります（例: `claude.ai` は許可済みでも Cloudflare のボットチャレンジで 403、`api.anthropic.com` は GET `/` に 404）。拒否かどうかは**本文が `Blocked by network policy` で始まるか**で判別します。

実機検証で判明した点として、**デフォルトポリシーは `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していません**。前者はエージェントの対話ログイン（OAuth）、後者は OpenCode の認証・更新で必要になり得るため、kit の allow に追加しています。テレメトリ系（`sentry.io` 等）は拒否のままが望ましい状態です。

## タスク用シークレット

devcontainer の pass-cli 方式は**この環境には持ち込みません**。sbx のネイティブ機構を使います:

```bash
# ホスト側で、対象の sandbox にスコープして登録。値は対話プロンプトで入力する
# （名前は kit の credentials の service 名に合わせる。グローバル登録 -g は
#   他リポジトリの sandbox にも波及するため使わない）
sbx secret set example --sandbox <sandbox名>
```

その上で kit の `credentials` にエントリを追加すると（spec.yaml 内にコメントアウトの雛形あり）、指定ドメイン宛のリクエストに限りホスト側プロキシがヘッダを注入します。VM 内の対応する環境変数（`apiKey.name`）には sentinel 値が入り、実値は送信直前にプロキシがヘッダを書き換える形でのみ使われます。kit の変更反映は sandbox の作り直し（`sbx rm` → 再 `run`）が必要ですが、sandbox-scoped の secret 自体は実行中でも即時反映されます。

pass-cli 方式との違い:

| | pass-cli（devcontainer） | sbx credential 注入 |
|---|---|---|
| 値の所在 | コンテナ内（PAT ファイル + セッション） | ホストのみ。**VM に実値が入らない** |
| 注入単位 | コマンド単位の環境変数（`pass-cli run`） | ドメイン限定の HTTP ヘッダ |
| 侵害時の想定 | コンテナ侵害 = PAT 侵害（vault スコープで限定） | VM 侵害でも値は漏れない（許可ドメインへの悪用のみ） |
| 失効運用 | Proton 側で revoke | `sbx secret` の差し替え + 発行元で revoke |
| スコープ | プロジェクト別 vault | sandbox 単位（`-g` のグローバル登録は使わない） |

環境変数としてシークレットの実値が必要なツール（ヘッダ注入で賄えないもの）が出てきた場合は、値が VM に入るトレードオフを理解した上で個別に検討してください。

### トークンを画面・履歴に残さず登録する

`sbx secret set` の `-t/--token` は、CLI リファレンス自身が **"less secure: visible in shell history"** と注記しているとおり、値をコマンドラインに書く形になります。本テンプレートでは使いません。代わりに次のいずれかを使ってください:

| 方法 | コマンド | 値の所在 |
|---|---|---|
| 対話入力（既定） | `sbx secret set <service> --sandbox <sandbox名>` | sbx の secret ストア |
| パスワードマネージャ参照 | `sbx secret set <service> --sandbox <sandbox名> --ref "op://<vault>/<item>/<field>"` | パスワードマネージャ（sbx は参照だけを保存） |
| 任意コマンドの出力 | `sbx secret set <service> --sandbox <sandbox名> --command '<値を stdout に出すコマンド>'` | 同上 |

- **`-t` を省くと値の入力を対話で求められます。** コマンドラインにもシェル履歴にも残りません。GitHub の画面で発行した PAT をコピペする、といったケースはこれが最短です
- **`--ref`** は 1Password の `op://` 参照と AWS Secrets Manager の ARN を受け付けます。対応する `op` / `aws` CLI がホストにインストール済み・認証済みである必要があります
- **`--command`** はホスト側でコマンドを実行し、その標準出力を値として使います。`--ref` が対応していないパスワードマネージャ（devcontainer 側で使っている Proton Pass の `pass-cli` など）はこちらで賄えます。`--command 'gh auth token'` も動きますが、それはユーザー全体のトークンであり、「リポジトリ単位のスコープ限定 PAT を、そのリポジトリの sandbox にだけ渡す」という本テンプレートの方針からは外れます
- `--ref` / `--command` は**値そのものではなく取得元を保存**します。sbx が必要になったタイミングでホスト側で解決し、`--refresh`（既定 55m）に従ってキャッシュするため、失効時の差し替えが発行元だけで済みます
- `--show-error`（source の検証に失敗したとき resolver の stderr を表示）は**エラー出力にシークレットが混じり得る**と注記されています。常用しないこと
- やむを得ず `-t` を使う場合も、値を直接書かずコマンド置換にしてください（例: `-t "$(op read 'op://…')"`）。履歴には値が残りませんが、実行中は `ps` のプロセス引数に見えます

> 対話プロンプトの有無は CLI のバージョンに依存し得ます。`-t` 無しで実行してプロンプトが出ない場合は `sbx secret set --help` を確認し、`--ref` / `--command` 側を使ってください。

## Chrome DevTools MCP（画面の見た目のデバッグ）

devcontainer と同様、エージェントは VM 内の headless Chromium で開発サーバーの画面を確認できます。sandbox 内での確認方法:

```bash
claude mcp list                      # chrome-devtools が登録されていること
/usr/local/bin/chromium-no-sandbox --version
```

エージェントに「example.com のスクリーンショットを撮って」等で動作確認できます。Codex は kit が seed する `~/.codex/config.toml` の `[mcp_servers.chrome-devtools]` で同じものを参照します。

## オーケストレーション（1 sandbox に複数エージェント）

sandbox はテンプレートイメージ単位（= 親エージェント単位）ですが、kit が委譲先の CLI を同居させるため、**claude sandbox は Claude Code を親にしたオーケストレーション環境**として使えます:

- kit は Codex CLI / OpenCode CLI をインストールし（テンプレート同梱済みならスキップ）、Codex を Claude Code のプラグイン（codex-rescue サブエージェント + `/codex` スキル）として登録します — devcontainer の `post-create.sh` と同じ構成です。
- `~/.codex/config.toml` の seed（`approval_policy = "on-request"` / `approvals_reviewer = "auto_review"` / `sandbox_mode = "workspace-write"` — CLI の `--approve-for-me` 相当）も共通なので、Claude からの委譲実行が承認待ちで止まりません。エスカレーションされた要求は人間ではなく自動レビューへ回ります。
- 委譲先の認証は 2 通り: sandbox 内で対話ログイン（`codex login` 等。`sbx rm` まで永続）、または組み込みサービスのプロキシ注入（`sbx secret set openai --sandbox <sandbox名>` — API キーの実値を VM に入れない。ChatGPT サブスクリプション認証を使う場合は対話ログイン一択）。
- codex / opencode 単体実行用の sandbox では、これらのステップは `command -v` ガードで no-op になります。

なお **sandbox をまたいだ協調は基本できません**（ファイルシステム・ネットワークとも隔離。clone モードでは各 sandbox が独立したクローンを持つため、受け渡しは GitHub 経由の push / fetch になります）。密結合のオーケストレーションは 1 つの claude sandbox に同居させてください。

## ホスト試用チェックリスト

併存期間の評価に使う確認項目です。上から順に（**4 の方式 A・6〜12 は clone モードの claude sandbox で実施済み** — 詳細は「既知の未確認事項」参照。残るのはホスト側項目 1〜3・5・13・14 と、4 の方式 B）:

1. `sbx version` — インストール確認
2. `sbx login` — Docker アカウントへのサインイン（ブラウザのデバイスコードフロー）
3. `sbx kit validate ./.sandbox/kit` / `sbx kit validate ./.sandbox/claude-auto` / `sbx kit validate ./.sandbox/codex-approve` — kit スキーマの検証（fork kit 2 つは未検証。`extends:` の解決も含めてここで確認する）
4. 起動モードの上書きを確認（どちらの方式を採るかで分岐。両方試して比較するのが望ましい）:
   - **方式 A（claude テンプレートでは検証済み）**: `sbx create --name claude-auto-<ディレクトリ名> --clone --kit ./.sandbox/kit claude .` → `sbx exec -it -w "$PWD" claude-auto-<ディレクトリ名> claude --permission-mode auto`。**サブスクリプション認証のまま起動できること**（再ログインを求められないこと）が最重要の確認点
   - **方式 B**: `sbx run claude-auto --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto`。認証が API キー登録（`sbx secret set anthropic`）を要求するはずなので、その挙動も確認する
   - いずれも VM 内で `git remote -v` / `ls /run/sandbox/source` が clone モードであること、`ps -eo args | grep claude` が `claude --permission-mode auto` を示すこと（**`--dangerously-skip-permissions` が残っていないこと**）を確認
5. `sbx secret set github --sandbox claude-auto-<ディレクトリ名>` → `sbx secret ls` でスコープが sandbox 単位（グローバルでない）ことを確認
6. VM 内: `node -v`（24 系）/ `pnpm -v`（11.9.0）/ `cat ~/.config/pnpm/config.yaml`（storeDir が agent の home を指す）/ `/usr/local/bin/chromium-no-sandbox --version`
7. `pnpm install --frozen-lockfile && pnpm test` が通る（TTY 無しで purge 確認に阻まれる場合は `CI=true` を付ける）
8. `claude mcp list` に chrome-devtools が出て、スクリーンショットが撮れる（**local スコープに登録されていると一覧に出ない** — kit は `-s user` で登録する）
9. `gh api user` が成功する（`echo "$GH_TOKEN"` が sentinel 値であること = 実値が VM に無いことの確認）。`git ls-remote` / `git push --dry-run` も試す
10. `sbx policy ls` の監査。許可外ドメインへの `curl` が拒否されること
11. Codex も 4 と同じ方式で起動 — `cat ~/.codex/config.toml` で `${WORKDIR}` が実パスに展開されていること、MCP が動くこと、`ps -eo args | grep codex` が `codex --approve-for-me` を示すこと（ChatGPT サブスクリプション認証が維持されるかもここで確認）
12. `sbx run opencode --clone --kit ./.sandbox/kit` — 起動とタスク実行
13. 一度抜けて再度入る → 再接続（install が走らない）。`sbx rm` → 作り直しで install が走る。**方式 A では再接続も `sbx exec` で行う**（`sbx run` で入ると既定の YOLO entrypoint が起動する）
14. VM 内でコミットして `git push` → GitHub に反映されること。ホスト側から `git fetch sandbox-claude-auto-<ディレクトリ名>` でも取り出せること

## トラブルシューティング（認証まわり）

`sbx` には `gh auth status` に相当する専用コマンドは（現時点のドキュメント上）見当たりません。実用上は **`sbx ls` が認証プローブ**になります — 認証が生きていれば sandbox 一覧（空でも正常終了）、壊れていれば認証エラーがそのまま出ます。`sbx --help` で `account` / `logout` 系のサブコマンドが増えていないかも確認してください。

「cannot prompt the user for password」「store is locked」「secret not found」等の認証エラーが `sbx login` でも解消しない場合、バックグラウンドの `sandboxd` デーモンが認証ストアのロックを握っている・認証メタデータが壊れている事例が報告されています。復旧手順（macOS）:

```bash
# 1) sandboxd を停止
pkill sandboxd   # または ~/.docker/caches/com.docker.sandboxes/ 下の sandboxd.pid の PID を kill

# 2) ロックファイルを削除
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock

# 3) 認証メタデータをクリア（sandbox 本体ではなく auth 側のみ）
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/

# 4) 任意のコマンドでデーモンを再起動し、再認証をトリガー
sbx ls
sbx login
```

sandbox 内のデータ（`com.docker.sandboxes` 側）は消さないよう注意してください。

**SSH / headless セッションの制約:** sbx は認証情報を OS のキーチェーン（macOS は Keychain、Linux は Secret Service/D-Bus）に保存します。SSH 越しや headless セッションではキーチェーンが施錠されたまま・プロンプトを表示できないため、`sbx login` が「saving credentials: cannot prompt the user for password」で失敗します（[docker/sbx-releases#180](https://github.com/docker/sbx-releases/issues/180) / [#186](https://github.com/docker/sbx-releases/issues/186) と同系統）。対処:

- **macOS に SSH している場合**: 同じシェルで先にキーチェーンを解錠してから再試行する — `security unlock-keychain ~/Library/Keychains/login.keychain-db`。それでも通らない場合は、一度だけローカルの GUI セッション（実機または画面共有のターミナル）で `sbx login` を済ませる
- **headless Linux の場合**: session D-Bus + `gnome-keyring-daemon --components=secrets` を起動し、`DBUS_SESSION_BUS_ADDRESS` を `sbx` とデーモンの双方に継承させる（#186 参照）
- いずれも sbx は認証まわりの修正が活発なので、`brew upgrade sbx` 等で最新化してから試す

## 既知の未確認事項

spec.yaml は [kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/) に基づきます。

**実機検証で判明済み**（claude テンプレート `docker/sandbox-templates:claude-code-docker`）:

- ベースは Ubuntu 26.04 / arm64、同梱 Node は v22（kit が 24 系へ更新する）、`~/.codex` は空（kit の設定 seed が有効に働く）、agent ユーザーは passwordless sudo + docker グループ、VM 内 Docker は 29.7.1
- apt の `chromium` は候補なし・`chromium-browser` は snap 移行パッケージのため、kit は Playwright 配布の Chromium を使う。実績は **playwright 1.62.1 / chromium-1234（Chromium 151.0.7922.34）** で、spec.yaml はこのバージョンに固定済み
- `~/.codex/config.toml` の `${WORKDIR}` はワークスペースの絶対パスへ展開される
- **git push (https) はヘッダ注入で通る** — `format: "token %s"` で `gh api user` / `git push` とも成功。「push はホスト側で行う」というフォールバックは不要
- ネットワークは deny-by-default が実際に効く（許可外ドメインは 403 `no matching allow rule`）。`GH_TOKEN` の中身は sentinel（`proxy-managed`）で実値は VM に無い
- **`claude mcp add` の既定スコープは local**（cwd 単位）で、install ステップの cwd はワークスペースとは限らない。既定のまま登録すると `claude mcp list` に出ないため、kit は `-s user` を指定している

**clone モードでの再検証（`sbx run claude --clone --kit ./.sandbox/kit`）で判明済み**:

- チェックリスト 4・6〜12 を再走して全項目パス。clone モード固有の問題は出ていない
- ワークスペースのパスは **clone モードでもホストの絶対パスをミラーする**（`/Users/.../pnpm-biome-template`）。`${WORKDIR}` もそのパスへ展開されるため、`~/.codex/config.toml` の `[projects."..."]` は direct モードと同じ結果になる。テンプレート由来の `/home/agent/workspace` は空ディレクトリとして残るだけで実害はない
- 導入結果: Node v24.19.0（同梱 v22 から kit が更新）/ pnpm 11.9.0（`packageManager` と一致）/ storeDir は `/home/agent/.pnpm-store`（**作業ツリーに `.pnpm-store` は作られない**）/ Chromium 151.0.7922.34 / `chrome-devtools-mcp` 1.7.0 / `@openai/codex` 0.149.1 / `opencode-ai` 1.18.23 / `codex@openai-codex` プラグイン 1.0.6
- `claude mcp list` に chrome-devtools が user スコープで出て接続 OK。**MCP 経由のスクリーンショットで日本語も豆腐にならない**（`fonts-noto-cjk` が効いている）
- `pnpm install --frozen-lockfile` → `pnpm release-check` が `CI=true` 付きで通る
- **デフォルトポリシーが `console.anthropic.com` / `claude.ai` / `opencode.ai` を許可していない**ことを実測（403）。kit の allow に追加済み（「ネットワークポリシーの監査」参照）
- VM 内で `pkill -f <パターン>` を使うと自分自身のシェルにマッチして落ちる。`agentInstructions` に PID 経由で止めるよう明記した
- **組み込み claude テンプレートの既定起動コマンドが `claude --dangerously-skip-permissions` であることを VM 内の `ps` で実測**。共有 mixin（= `sandbox:` ブロックを持てない）だけでは上書きできない（「YOLO 既定の上書き」参照）
- **組み込みエージェントの認証はプロキシ管理であることを確認** — `~/.claude/.credentials.json` の `claudeAiOauth.accessToken` / `refreshToken` はいずれも 26 文字で、`GH_TOKEN`（13 文字、`prox…` で始まる）と同種の sentinel。実 OAuth トークンは VM に入っていない

**方式 A（`sbx create` + `sbx exec`）での検証で判明済み**（`sbx create --clone --kit ./.sandbox/kit claude .` → `sbx exec -it -w "$PWD" <sandbox名> claude --permission-mode auto`、claude テンプレート + Claude Max）:

- `sbx create` はエージェントを起動せずに kit の install を完走し、`sbx exec` で立ち上げたプロセスは `ps` 上 **`claude --permission-mode auto`**（`--dangerously-skip-permissions` は残らない）。既定の YOLO entrypoint を踏まずに済む
- **サブスクリプション認証はそのまま維持され、再ログインを求められない。** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` はいずれも未設定で、`~/.claude/.credentials.json` の token 類は 26 文字の sentinel のまま（＝実値は VM に無い）
- 権限判断が実際に効いていることも確認 — `~/.claude/.credentials.json` の値を表示しようとしたコマンドが auto モードの classifier に拒否された
- チェックリスト 6〜12 を再走して全項目パス（Node v24.20.0 / pnpm 11.9.0 / storeDir `/home/agent/.pnpm-store` / Chromium 151.0.7922.34 / `chrome-devtools` MCP 接続 OK / `codex@openai-codex` 1.0.6 / `gh api user`・`git ls-remote`・`git push --dry-run` 成功 / `CI=true pnpm install --frozen-lockfile` → `pnpm release-check` 通過）
- **`claude.ai` は 403 を返すが、本文は Cloudflare のボットチャレンジページでポリシーとしては通過している。** ポリシー拒否かどうかは本文が `Blocked by network policy` かで判別すること（`example.com` / `sentry.io` は拒否のまま）
- `claude mcp list` に kit 由来でない **`mcp-gateway`**（`http://mcp-gateway.docker.internal/mcp`）が登録・接続されている。sbx 側が用意しているものと思われる
- `claude mcp list` 冒頭に「claude.ai connectors are disabled because ANTHROPIC_API_KEY or another auth source is set」という警告が出るが、API キーは未設定であり、プロキシ管理の credential が "another auth source" と判定されているため。無効になるのは claude.ai 側の organization connectors だけで、Claude Code 自体の動作には影響しない

残る未確認事項。判明したら spec.yaml とこの節を更新してください:

1. **codex / opencode テンプレートでの同挙動** — 上記の確認は claude テンプレートのみ。特に codex テンプレートが `~/.codex/config.toml` を seed している場合、`onlyIfMissing` により kit 側の設定は入らない
2. **`sbx rm` を跨いだ secret の永続性** — sandbox 名スコープで登録した secret が sandbox 再作成後も残るかは未確認。作り直したら `gh api user` で再確認すること
3. **ホスト側でしか確認できない項目**（VM 内に `sbx` は無いため未実施）— チェックリスト 5（`sbx secret ls` のスコープ）・13（再接続で install が走らない / `sbx rm` 後は走る）・14 後半（`git fetch sandbox-claude-auto-<ディレクトリ名>`）
4. **YOLO 既定の上書きは方式 B が未検証**（方式 A は claude テンプレートで検証済み — 上記参照）:
   - **方式 B（fork kit）** — `sbx kit validate` が通ること、mixin と fork kit の `--kit` 二重指定が両方適用されること、`ps` の起動引数から `--dangerously-skip-permissions` が消えていること、OAuth 非対応の制約が実際にどこで顕在化するか。`entrypoint` と `command` の継承がどう解決されるか（親の bypass フラグがどちらに入っているか）は公開されていないため、**`ps` での実測を必ず行ってください**
   - **方式 A の codex 側** — codex テンプレート + ChatGPT サブスクリプションで同じ手順が通るか（`sbx exec -it -w "$PWD" <sandbox名> codex --approve-for-me`、チェックリスト 11）

## 将来フェーズ: devcontainer からのエージェント除去の判断基準

以下がすべて満たされたら、devcontainer を「人間の VS Code 開発環境」へ縮退させる（別 PR）:

- sbx 側で日常タスク一式（テスト実行 / MCP での画面確認 / gh・PR 操作 / Codex・OpenCode の無人実行）が 2〜4 週間、devcontainer にフォールバックせず回っている
- pass-cli の全ユースケース（gh、git push、タスク用 API キー）が credential 注入で代替できている
- 除去範囲を確定できている: `post-create.sh` のエージェント導入 + MCP ブロック、`Dockerfile` の Chromium / pass-cli レイヤ、`compose.yaml` の認証 volume 群、`codex-config.toml`、README の pass-cli 節。Pi（sbx 非対応）を使い続けるかどうかもこのとき判断する
