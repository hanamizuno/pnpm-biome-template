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

```bash
# 1) リポジトリの checkout ディレクトリで、kit を適用してエージェントを起動。
#    sandbox 名は自動で `<agent>-<ディレクトリ名>`（例: claude-pnpm-biome-template）
#    になり、エージェントごと・リポジトリごとに別 sandbox になる。
#    起動時に kit の credentials 利用確認が出るので Approve する
#    （ここで No にするとプロキシ注入が効かない）。
cd <このリポジトリの checkout>
sbx run claude --kit ./.sandbox/kit

# 2) GitHub の fine-grained PAT を、その sandbox だけにスコープして登録
#    （第 1 引数は自動命名された sandbox 名。`sbx ls` で確認できる。
#      名前 `github` は kit の credentials の service 名と対応する。
#      sandbox-scoped の secret は実行中の sandbox にも即時反映される。
#      スコープ方針は .devcontainer/README.md「GitHub 権限の制限（PAT）」と同じ —
#      リポジトリ単位のスコープ限定 PAT を、そのリポジトリの sandbox にだけ渡す。
#      値は VM に入らず、プロキシが GitHub 宛リクエストのヘッダにのみ注入する）
sbx secret set claude-<ディレクトリ名> github

# Codex / OpenCode も同様（sandbox ごとに secret を登録する）
sbx run codex --kit ./.sandbox/kit
sbx run opencode --kit ./.sandbox/kit
```

同一ワークスペース・同一エージェントで複数の sandbox を並行させたい場合のみ `--name` で明示的に名前を付けます。

> **`-g`（グローバル）は使わない:** `sbx secret set -g github` はユーザー全体のグローバル登録で、**以後作成するすべての sandbox（他リポジトリ含む）に注入され得ます**。`github` のような組み込みサービスは kit の宣言が無くても provenance で自動注入されるため、グローバル登録は「リポジトリごとに権限を区切る」本テンプレートの方針に反します。sandbox 名スコープで登録してください（グローバル値があっても sandbox-scoped が優先されます）。なお `sbx secret set` の引数形式は CLI バージョンで異なることがあります（`sbx secret set <sandbox名> <service>` / `sbx secret set <service> --sandbox <sandbox名>`）— `sbx secret set --help` で確認してください。

初回はエージェントごとの認証（Claude はブラウザログイン等）が必要です。認証を含む sandbox 内の状態は `sbx rm` するまで永続します。

kit（[kit/spec.yaml](kit/spec.yaml)）が sandbox 作成時にセットアップする内容:

- Node 24 + corepack + pnpm（`package.json` の `packageManager` と同じバージョン）
- headless Chromium + 日本語フォント + `/usr/local/bin/chromium-no-sandbox` ラッパー（devcontainer と同一パス。Chromium 本体は Debian 系なら apt、Ubuntu 系テンプレートでは apt の chromium が snap 移行パッケージのため Playwright 配布の linux-arm64 ビルドを使用）
- `chrome-devtools-mcp` のグローバルインストールと Claude Code への登録
- Codex の初期設定 seed（`~/.codex/config.toml`。既存があれば上書きしない）
- 委譲先 CLI（Codex / OpenCode）の導入と、Claude Code への Codex プラグイン登録（下記「オーケストレーション」参照。テンプレート同梱済み・claude 不在の sandbox では no-op）
- ネットワーク許可リストの追加と GitHub PAT のヘッダ注入設定

## 日常運用

- 同じワークスペースで `sbx run` すると**既存 sandbox に再接続**します（install は再実行されない）
- `sbx ls` で一覧、`sbx stop <name>` で停止、`sbx rm <name>` で削除（VM 内の全状態が消える。ワークスペースのファイルはホストに残る）
- kit を更新したら `sbx rm` → 再 `sbx run --kit ...` で作り直して反映する（`sbx kit add` は `setup.files` を含む kit を受け付けないため、この kit には使えない）
- 同一ワークスペースで並行作業したい場合は `--name` で別名の sandbox を作る

## direct モードの注意

ワークスペースは direct モード（ホストのファイルシステムをパススルー）で、**VM 内でもホストの絶対パス（`/Users/...` 等）のまま**見えます。エージェントの編集は即ホストの作業ツリーに反映されます。

**同じ checkout に対してホスト側で `pnpm install` を実行しないでください。** `node_modules` がホストとそのまま共有されるため、macOS バイナリと Linux バイナリが衝突します。devcontainer は named volume で `node_modules` をマスクしているため、**devcontainer と sbx の共存は問題ありません**（衝突するのはホスト macOS ↔ sbx の組み合わせのみ）。より強くホストと切り離したい場合は clone モード（`sbx run --clone`）も使えます。

## ネットワークポリシーの監査

外向き通信は deny-by-default ですが、**デフォルトの許可リストには広い wildcard が含まれます**。初回に必ず確認してください:

```bash
sbx policy ls
```

kit の `permissions.network.allow` は**デフォルトポリシーへの追加**であり、デフォルト側の広い許可を削るものではありません。実効ポリシーを絞るのはホスト側の `sbx policy` 操作で行います（deny は allow より優先されるため、kit に `permissions.network.deny` を足して特定ドメインを塞ぐこともできます）。kit の allow（npm registry / 各エージェントの API / GitHub / apt リポジトリ）だけで回る状態が理想です。

## タスク用シークレット

devcontainer の pass-cli 方式は**この環境には持ち込みません**。sbx のネイティブ機構を使います:

```bash
# ホスト側で、対象の sandbox にスコープして登録
# （名前は kit の credentials の service 名に合わせる。グローバル登録 -g は
#   他リポジトリの sandbox にも波及するため使わない）
sbx secret set <sandbox名> example
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
- `~/.codex/config.toml` の seed（`approval_policy = "never"` / `sandbox_mode = "workspace-write"`）も共通なので、Claude からの委譲実行が承認待ちで止まりません。
- 委譲先の認証は 2 通り: sandbox 内で対話ログイン（`codex login` 等。`sbx rm` まで永続）、または組み込みサービスのプロキシ注入（`sbx secret set <sandbox名> openai` — API キーの実値を VM に入れない。ChatGPT サブスクリプション認証を使う場合は対話ログイン一択）。
- codex / opencode 単体実行用の sandbox では、これらのステップは `command -v` ガードで no-op になります。

なお **sandbox をまたいだ協調は基本できません**（ファイルシステム・ネットワークとも隔離。direct モードの共有ワークスペース経由のファイル受け渡しのみ）。密結合のオーケストレーションは 1 つの claude sandbox に同居させてください。

## ホスト試用チェックリスト

併存期間の評価に使う確認項目です。上から順に:

1. `sbx version` — インストール確認
2. `sbx login` — Docker アカウントへのサインイン（ブラウザのデバイスコードフロー）
3. `sbx kit validate ./.sandbox/kit` — kit スキーマの検証
4. `sbx run claude --kit ./.sandbox/kit` — 初回作成と認証（credentials 確認は Approve）。VM 内で `pwd` がホストの絶対パスであること
5. `sbx secret set claude-<ディレクトリ名> github` → `sbx secret ls` でスコープが sandbox 単位（グローバルでない）ことを確認
6. VM 内: `node -v`（24 系）/ `pnpm -v`（11.9.0）/ `cat ~/.config/pnpm/config.yaml`（storeDir が agent の home を指す）/ `/usr/local/bin/chromium-no-sandbox --version`
7. `pnpm install --frozen-lockfile && pnpm test` が通る
8. `claude mcp list` に chrome-devtools が出て、スクリーンショットが撮れる
9. `gh api user` が成功する（`echo "$GH_TOKEN"` が sentinel 値であること = 実値が VM に無いことの確認）。`git ls-remote` / push も試す
10. `sbx policy ls` の監査。許可外ドメインへの `curl` が拒否されること
11. `sbx run codex --kit ./.sandbox/kit` — `cat ~/.codex/config.toml` で `${WORKDIR}` が実パスに展開されていること、MCP が動くこと
12. `sbx run opencode --kit ./.sandbox/kit` — 起動とタスク実行
13. 一度抜けて再 `sbx run` → 再接続（install が走らない）。`sbx rm` → 再 `run` で install が走る

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

**実機検証で判明済み**（claude テンプレート `docker/sandbox-templates:claude-code-docker`）: ベースは Ubuntu 26.04 / arm64、同梱 Node は v22（kit が 24 系へ更新する）、`~/.codex` は空（kit の設定 seed が有効に働く）、agent ユーザーは passwordless sudo + docker グループ。apt の `chromium` は候補なし・`chromium-browser` は snap 移行パッケージのため、kit は Playwright 配布の Chromium を使う。

残る未確認事項。判明したら spec.yaml とこの節を更新してください:

1. **codex / opencode テンプレートでの同挙動** — 上記の確認は claude テンプレートのみ。特に codex テンプレートが `~/.codex/config.toml` を seed している場合、`onlyIfMissing` により kit 側の設定は入らない
2. **git push (https) がヘッダ注入で通るか** — git は `Authorization: Basic` を使うため、kit の `format: "token %s"` と形式が合わない可能性がある。通らない場合は「push はホスト側で行う」を初期運用とする
3. **Playwright のバージョン固定** — 初回成功後に sandbox 内で `npx playwright --version` を確認し、spec.yaml の `playwright@latest`（2 箇所）を実績バージョンに固定する（chrome-devtools-mcp と同じ再現性の方針）

## 将来フェーズ: devcontainer からのエージェント除去の判断基準

以下がすべて満たされたら、devcontainer を「人間の VS Code 開発環境」へ縮退させる（別 PR）:

- sbx 側で日常タスク一式（テスト実行 / MCP での画面確認 / gh・PR 操作 / Codex・OpenCode の無人実行）が 2〜4 週間、devcontainer にフォールバックせず回っている
- pass-cli の全ユースケース（gh、git push、タスク用 API キー）が credential 注入で代替できている
- 除去範囲を確定できている: `post-create.sh` のエージェント導入 + MCP ブロック、`Dockerfile` の Chromium / pass-cli レイヤ、`compose.yaml` の認証 volume 群、`codex-config.toml`、README の pass-cli 節。Pi（sbx 非対応）を使い続けるかどうかもこのとき判断する
