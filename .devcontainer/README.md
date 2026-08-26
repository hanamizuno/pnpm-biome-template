# AI Agent Dev Container

Dev Container は AI コーディングエージェント（Claude Code / Codex 等）の実行環境も兼ねます。エージェントのツールチェーンは [Dev Container Features](https://containers.dev/implementors/features/) と post-create セットアップで Node.js + pnpm の開発環境に重ねて注入されるため、プロジェクト固有の `claude/` ディレクトリは不要です。コンテナ定義は Docker Compose ベースの `.devcontainer/compose.yaml`（ルートの `compose.yml` / `compose.dev.yml` とは別物）で、個人環境向けの差分は gitignore 済みの `compose.local.yaml` に書けます — 下記「ローカルオーバーライド（compose.local.yaml）」参照。

## 同梱エージェントツール

| ツール | ソース |
|---|---|
| 共通ユーティリティ（非 root の `vscode` ユーザー、sudo、各種パッケージ） | `ghcr.io/devcontainers/features/common-utils` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code` |
| Codex CLI | `post-create.sh` が `npm install -g @openai/codex` でインストール |
| Codex プラグイン（Claude Code 用） | `post-create.sh` が `claude plugin install codex@openai-codex` でインストール。Claude Code から必要に応じて Codex に委譲できる（`codex-rescue` サブエージェント + `/codex` スキル） |
| OpenCode | `post-create.sh` が `npm install -g opencode-ai` でインストール |
| Pi | `post-create.sh` が `npm install -g @earendil-works/pi-coding-agent` でインストール |
| Chrome DevTools MCP（見た目のデバッグ用） | リポジトリルートの `Dockerfile` の `devcontainer` ステージが headless Chromium + 日本語フォントを導入し、`post-create.sh` が `chrome-devtools-mcp` をインストールして Claude Code に登録（Codex には `codex-config.toml` で登録） |

各 Feature は再現性のため `devcontainer.json` で `sha256` digest 固定されています。Node.js / pnpm は本リポジトリの `Dockerfile` の `devcontainer` ステージで導入しています（言語ランタイムは Dockerfile 側、エージェントツールは Features / post-create 側、という方針）。

post-create 管理のエージェント（Codex / OpenCode / Pi）は `post-create.sh` 冒頭の `AGENTS` 配列で選択します。配列の行をコメントアウトすると、そのエージェントのインストールと関連セットアップ（設定 seed、Claude Code プラグイン登録など）がスキップされます。無効化は非破壊で、インストール済みコンテナからのアンインストールはしません — 反映にはコンテナの rebuild が必要で、認証 volume はそのまま残ります（再有効化すれば再ログイン不要）。恒久的にローカルだけ選択を変えたい場合は、gitignore したファイル（例 `agents.local.sh`）で `AGENTS` を上書きするよう `post-create.sh` に `source` を 2 行足せば後付けできます。

別の エージェント CLI（Cursor 等）を追加したい場合は、上流の Feature、`./<feature-id>/` 配下のローカル Feature、もしくは `post-create.sh` への冪等な `install_<name>` 関数 + `AGENTS` 配列 1 行（認証を永続化するなら `compose.yaml` の volume と `Dockerfile` のマウントポイント事前作成も）のいずれかを追記してください。

## 初回セットアップ

1. **コンテナを起動** — VS Code の「Reopen in Container」、もしくはヘッドレスに `devcontainer up --workspace-folder .`
2. **認証**（初回のみ。ホストから bind mount せず、固定名の compose named volume に永続化されるため、リビルド後も再ログイン不要）:
   - **Claude Code**: そのままエージェントを起動すれば、初回はインラインでログインフローが表示されます。`/login` を CLI 引数で渡さないこと — それはアクティブセッション用のスラッシュコマンドで、ホストシェルから使うとフローが二重に起動します。
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: エージェントを起動して ChatGPT でサインインします。API キー課金を使う場合は、ホストシェルへの export や `remoteEnv` パススルーではなく、`.env` の `pass://` 参照 + `pass-cli run --env-file .env -- codex` で渡してください（下記「タスク用シークレット（Proton Pass / pass-cli）」参照）。初回のコンテナ作成時に `codex-config.toml` が永続化される `~/.codex/config.toml` ボリュームにコピーされます。同じ post-create ステップで Claude Code の `~/.claude` ボリュームに `codex@openai-codex` プラグインもインストールされるため、Claude Code がセッションごとの再インストールなしに Codex を呼び出せます（`codex-rescue` サブエージェント + `/codex` スキル）。
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **OpenCode**: `auth login` でプロバイダを選んでログインします（認証は `opencode-data` volume の `auth.json` に保存）。
     ```bash
     devcontainer exec --workspace-folder . opencode auth login
     ```
   - **Pi**: エージェントを起動して `/login` でプロバイダにログインします（認証は `pi-config` volume の `agent/auth.json` に保存）。API キー課金を使う場合は Codex と同様に `.env` の `pass://` 参照 + `pass-cli run --env-file .env -- pi` で渡してください。
     ```bash
     devcontainer exec --workspace-folder . pi
     ```
   - **GitHub CLI** — 以下のいずれか:
     - **Web フロー**（対話。OAuth スコープはログイン時に選択）:
       ```bash
       devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web
       ```
     - **ホストのトークンを流し込む**（例: `gh auth token` の出力）:
       ```bash
       devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_TOKEN \
         sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
       ```
     - **スコープ限定 PAT**（自律実行向けに推奨） — 下記「GitHub 権限の制限（PAT）」を参照。
   認証情報は compose named volume（`claude-config` / `codex-config` / `opencode-data` / `opencode-config` / `pi-config` / `gh-config`。実名は project 名プレフィックス付きで `pnpm-biome-template-devcontainer_claude-config` 等）に格納され、`--remove-existing-container` での再ビルド後も残ります。

## ホスト設定の継承

コンテナの作成/起動のたびに、`initialize.sh`（`initializeCommand`、ホスト側で実行）が選択されたホスト設定を `.devcontainer/` 配下の git-ignore されたファイルへステージングし、`post-start.sh` がコンテナ内へ反映します:

- **グローバル gitignore** — `core.excludesFile` → `~/.config/git/ignore`（XDG）→ `~/.gitignore` の順で解決し、シンボリックリンクを実体化（例: Nix / home-manager のターゲット）した上で `host-gitignore` としてステージングし、コンテナ内の `~/.config/git/ignore`（git の XDG デフォルト。`git config` には触れない）へコピーします。起動ごとに上書きされるため、ホストが常に正です。
- **Git identity** — `user.name` / `user.email` をホストのグローバル git config から読み取り（ファイルではなく値を読むため includes が解決され、credential helper などホスト専用設定は持ち込まれない）、`host-gituser` としてステージングし、起動ごとに `git config --global` でコンテナ内へ反映します。ホストで未設定のキーには触れません。
- **Claude Code の settings + statusline** — `~/.claude/settings.json` はホストのホームパスを `/home/vscode` に書き換えた上で（`statusLine` コマンド等が動き続けるように）ステージングし、コンテナ内の `~/.claude/settings.json` へ `jq` で **deep-merge** します（キー単位でホスト優先。コンテナ内でのプラグイン有効化などコンテナ専用キーは残る）。`~/.claude/statusline-command.sh` も併せてコピーします。認証・状態（`~/.claude.json`、`~/.claude/.credentials.json`）は意図的にステージング**しません** — 認証はコンテナスコープのボリュームに留まります。

ホスト側にファイルが存在しない場合、そのステップは no-op となりコンテナは通常どおり起動します。

ステージングされた `host-*` ファイル（`host-gitignore` / `host-gituser` / `host-claude/` / `host-proton-pat`）は個人設定を含む git-ignore されたローカル生成物です。`git clone` では持ち出されませんが、チェックアウトの単純なファイルコピー（`cp -r` や zip）には含まれるため、このテンプレートを git 外でコピーする場合は除外してください。特に `host-proton-pat` は `devcontainer up` からコンテナの post-start（がコンテナ内にコピーしてステージを削除する）までの間だけ本物のシークレットを保持するため、残留コピーを見つけたらそのトークンはローテーション対象と見なしてください。

> **Windows ホスト:** `initializeCommand` はホスト上で bash スクリプトを実行するため、ネイティブ Windows では Git Bash / WSL が `PATH` 上に必要です — 無い場合は同期がスキップされますが、コンテナ自体は起動します。

## ローカルオーバーライド（compose.local.yaml）

`devcontainer.json` の `dockerComposeFile` は `["compose.yaml", "compose.local.yaml"]` の 2 ファイル構成で、docker compose のマージ規則で順に合成されます。gitignore 済みの `.devcontainer/compose.local.yaml` に**差分だけ**を書けば、コミットせずに個人環境向けの bind mount / ネットワーク / extra_hosts を追加できます。列挙されたファイルが存在しないと docker compose が起動できないため、ファイルが無い場合は `initialize.sh` が no-op スタブ（`services: { app: {} }`）を自動生成します。

注意: compose の相対パスは project directory（= `.devcontainer/`）基準です。ワークスペースは `..`、リポジトリ隣接ディレクトリは `../../<name>` になります。

例 — リポジトリ隣接ディレクトリを read-only で bind mount する:

```yaml
services:
  app:
    volumes:
      - ../../<dir>:/<dir>:ro
```

target を `/<dir>` にすると、コンテナ内の `/workspace` からホストと同じ相対パス `../<dir>` で参照できます。

## 見た目のデバッグ（Chrome DevTools MCP）

エージェントは [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 経由でコンテナ内の headless Chromium を操作し、`pnpm dev` で立てた開発サーバーの画面をスクリーンショット・コンソールログ・ネットワークリクエストで確認できます。「この画面のレイアウト崩れを直して」のような依頼に対して、エージェントが自分で描画結果を見ながら修正→確認のループを回せます。

- **Claude Code**: `post-create.sh` が `claude mcp add chrome-devtools` で登録します（`~/.claude` ボリュームに永続化）。既存コンテナにはリビルド（post-create 再実行）で反映されます。
- **Codex**: `codex-config.toml` の `[mcp_servers.chrome-devtools]` で登録します。初回作成時にのみボリュームへコピーされる設定のため、既存の `~/.codex/config.toml` には同セクションを手動で追記してください。

技術メモ:

- Chromium は Debian の `chromium` パッケージを使用します（Apple Silicon ホストの arm64 コンテナでも動作。Google Chrome 公式 deb は amd64 のみのため不採用）。日本語の描画用に `fonts-noto-cjk` を同梱しています。
- コンテナ内ではカーネルサンドボックスが使えないため、`--no-sandbox` を付与する `/usr/local/bin/chromium-no-sandbox` ラッパー経由で起動します。信頼できないサイトの閲覧には使わず、ローカル開発サーバーの確認用としてください（コンテナ自体が隔離境界、という本テンプレートの方針の範囲内です）。
- MCP は `--isolated`（一時プロファイル）+ `--headless` で起動するため、表示用ディスプレイは不要です。利用統計の外部送信は `--no-usage-statistics` で無効化しています（隔離モードとの整合のため）。

## 動作モード

- **デフォルト（egress 開放）** — 送信トラフィックは制限しません。ホストの認証情報は bind mount せず（Claude / Codex / `gh` の認証はコンテナスコープのボリュームに格納）、ホストの Docker ソケットも露出しません。`--dangerously-skip-permissions` に対する防御面は「非 root の `vscode` ユーザー」「ワークスペース限定マウント」「コンテナスコープの認証ボリューム」の 3 点です。Codex はコンテナスコープの設定に `approval_policy = "never"` と `sandbox_mode = "workspace-write"` が seed されるため、書き込みをワークスペースに限定しつつ承認待ちなしで動作します。エージェントがネットワークアクセス付きで無人実行されるからこそ、タスク用シークレット（API キーやトークン）は ambient なコンテナ環境変数ではなく `pass-cli run` によるコマンド単位の注入で渡します — 下記「タスク用シークレット（Proton Pass / pass-cli）」参照。
- **隔離モード（任意）** — より厳格なサンドボックスにしたい場合は、egress 不可の Docker ネットワークを作成しコンテナをそこに接続します:
  ```bash
  docker network create --internal agent-internal
  ```
  `compose.local.yaml` にネットワーク接続を追加します:
  ```yaml
  services:
    app:
      networks: [agent-internal]
  networks:
    agent-internal:
      external: true
  ```
  完全に外向き通信が遮断されるため、切り替え前に依存（`pnpm install` 等）を解決しておき、エージェントが API アクセスを要する場合は別途プロキシサイドカーを用意してください。

## この隔離が担保しない範囲

コンテナは爆発半径を「ホストユーザーが触れるすべて」から「ワークスペース + コンテナスコープの認証ボリューム」まで圧縮しますが、あくまで Linux コンテナであり microVM ではありません。具体的に、このテンプレートは以下を提供**しません**:

- 独立したカーネル（コンテナエスケープにつながるカーネル脆弱性は封じ込められません）
- 細粒度のネットワーク allow/deny リスト（あるのは上記の `--network=internal` による二値の隔離モードのみ）
- エージェントセッション内から安全にコンテナをビルド・実行するためのネスト Docker デーモン（ホストの Docker ソケットは意図的にマウントしていません）

これらが必要な場合は、[Docker Sandbox](https://docs.docker.com/ai/sandboxes/)（microVM のカーネル境界、allow/deny ネットワーク、サンドボックスごとの Docker デーモン）のような、より保証の強いサンドボックス内でエージェントを動かし、この devcontainer は内側のワークスペースとして扱ってください。本リポジトリには Docker Sandboxes（`sbx`）用の kit を `.sandbox/` に同梱しています — [.sandbox/README.md](../.sandbox/README.md) 参照。

**ホストの loopback へのアクセスは意図的に開けていません。** `host.docker.internal` はデフォルトでは追加しません — 開けると `0.0.0.0` にバインドされたホストのサービス（ローカル LLM サーバー、開発用 DB、デバッグダッシュボード）がすべてエージェントから見えてしまいます。どうしても必要な場合（例: ローカルホストの OpenAI 互換エンドポイントをエージェントに使わせる）は、プロジェクトのデフォルトではなくローカルオーバーライドとして追加してください:

```yaml
# .devcontainer/compose.local.yaml (ユーザーごとのオーバーライド。コミットしない)
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

その上でホスト側のサービスを（`127.0.0.1` ではなく）`0.0.0.0` にバインドし、エージェントには `http://host.docker.internal:<port>` を使わせます。

## GitHub 権限の制限（PAT）

Claude Code を `--dangerously-skip-permissions` で動かすと、保存された `gh` トークンのスコープをそのまま引き継ぎます。爆発半径を絞るため、普段使いの `$GH_TOKEN` ではなく専用 PAT をボリュームに seed することを推奨します。

**手順:**

1. GitHub で PAT を発行:
   - **クイックリンク** — [事前入力済みテンプレート](https://github.com/settings/personal-access-tokens/new?name=agent-devcontainer&description=Agent%20devcontainer%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write)を開き（Repository permissions: `Contents: Write` / `Pull requests: Write` / `Issues: Write` / `Metadata: Read` / `Actions: Read` / `Workflows: Write`、有効期限 90 日）、対象リポジトリを選んで *Generate token* をクリック。URL のクエリを書き換えれば、より狭いテンプレートを派生できます（例: read-only のレビュー用トークンなら `pull_requests=write` を外す。workflow dispatch が必要なら `actions=read` を `actions=write` に上げる。エージェントに `.github/workflows/*.yml` を編集させないなら `workflows=write` を外す）。`Administration: Write` は意図的にベースラインに含めていません — リポジトリ作成や設定変更が実際に必要になったときに手動で追加してください。
   - **Fine-grained**（爆発半径を最小化したい場合に推奨） — 対象リポジトリと最小権限を下表から選択。
   - **Classic** — 必要なスコープが最小限になるよう設定（例: `repo` のみ）。`gh` のサブコマンドが fine-grained でまだ未対応な場合のフォールバック。
2. スコープが累積しないよう既存認証をログアウト:
   ```bash
   devcontainer exec --workspace-folder . gh auth logout --hostname github.com
   ```
3. 新しい PAT をボリュームに流し込む（値がシェル履歴に残らないよう先頭にスペースを置くか、ファイルから読み出す）:
   ```bash
    GH_PAT='github_pat_xxx' devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT=$GH_PAT \
      sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   unset GH_PAT
   ```
   トークンファイル経由:
   ```bash
   devcontainer exec --workspace-folder . --remote-env GH_TOKEN_INPUT="$(cat ~/.config/agent-gh-pat)" \
     sh -c 'printf "%s\n" "$GH_TOKEN_INPUT" | env -u GH_TOKEN gh auth login --hostname github.com --with-token'
   ```
4. 付与されたスコープを確認:
   ```bash
   devcontainer exec --workspace-folder . gh auth status
   devcontainer exec --workspace-folder . sh -c '
     gh auth token | xargs -I{} curl -sI -H "Authorization: token {}" https://api.github.com/user \
       | grep -iE "x-oauth-scopes|x-accepted"
   '
   ```
   Classic PAT は `x-oauth-scopes` で付与スコープが返ります。Fine-grained PAT はここが空になるため、PAT 設定画面のリソース権限を直接確認してください。

**最小権限の目安（fine-grained）:**

| Claude にさせたい操作 | 権限 |
|---|---|
| Issue / PR / リポジトリメタデータの読み取り | `Issues: Read`, `Pull requests: Read`, `Metadata: Read` |
| PR へのコメント / オープン / クローズ | `+ Pull requests: Write`, `Issues: Write` |
| HTTPS `git push` / コミット | `+ Contents: Write`（リポジトリスコープ） |
| GitHub Actions の読み取り / dispatch | `+ Actions: Read`（dispatch が必要なら `Write`） |
| `.github/workflows/` 配下の workflow YAML の編集 | `+ Workflows: Write` |
| リポジトリ作成 / 設定変更 | `+ Administration: Write`（organization では承認要の場合あり） |

**注意 / ハマりどころ:**

- Fine-grained PAT は `gh` の一部サブコマンドにまだ未対応です。403 や「PAT not supported」が返るときは最小スコープの Classic PAT にフォールバックしてください。
- トークンはボリューム内の `~/.config/gh/hosts.yml` に格納されます。コンテナ内でシェルが取れる人物は値を読めるため、コンテナの侵害＝トークンのスコープ範囲が侵害された、と見なしてください。
- ローテーションは手順 2 + 3 の繰り返しで OK（ボリュームを作り直す必要はありません）。
- 別解として、`.devcontainer/pass-relogin` が agent vault の `github-fine-grained` アイテムから `gh` 認証を seed します（ボリュームが未認証のときのみ。次節参照）。

## タスク用シークレット（Proton Pass / pass-cli）

このコンテナのエージェントは無人（`approval_policy = "never"`、`--dangerously-skip-permissions`）で動き、自分の環境変数はすべて読めます。そのためタスク用シークレットを ambient なコンテナ環境変数に置いてはいけません — `remoteEnv` / `containerEnv` によるパススルーがまさにそれに当たります（以前の `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` パススルーはこの理由で廃止）。代わりに [Proton Pass CLI](https://protonpass.github.io/pass-cli/) を devcontainer ステージに焼き込み、コマンド単位で注入します:

1. `.env`（git-ignore 済み）には `pass://SHARE_ID/ITEM_ID/FIELD` の**参照だけ**を書きます — `example.env` を `.env` にコピーして始めてください。参照は ID ベースです: URI に vault 名やアイテム名を書いても解決されません（pass-cli はそのまま素通しします）。ID は `pass-cli item list --vault-name <vault> --output json`（`share_id` / `id` フィールド）で調べられます。参照は識別子であって値ではないので `example.env` はコミット可能です。実体の `.env` は「本物のトークンをうっかり書いた」事故への保険として ignore のままにします。
2. シークレットが必要なコマンドは `pass-cli run` 経由で実行します:

   ```bash
   PROTON_PASS_AGENT_REASON="<何のための取得か>" pass-cli run --env-file .env -- <cmd>
   ```

   値は実行時に解決され、`<cmd>` の環境変数にのみ注入され、stdout/stderr では `<concealed by Proton Pass>` にマスクされます。`PROTON_PASS_AGENT_REASON` は PAT（エージェント）セッションでのアイテム参照に必須で（無いと `pass-cli run` はエラーで失敗します）、値は Proton の監査ログに記録されます。

**ログインの仕組み:** ホスト側で `initialize.sh` が 0600 のファイル — プロジェクト別の `~/.config/proton-pass-agent/<ディレクトリ名>` があればそれ、無ければ共有の `~/.config/proton-pass-agent/pat` — から Proton Pass の PAT を、git-ignore された `.devcontainer/host-proton-pat` としてステージングします — 上記「ホスト設定の継承」と同じ host-* ステージング方式のため、追加の mount はありません。`post-start.sh` がそれをコンテナ内の `~/.local/state/proton-pass-agent/pat`（0600）へコピーし、ステージを削除します。ログイン自体はエージェント主導です: pass-cli にセッションが無いとき、または認証エラーが出たとき、`.devcontainer/pass-relogin` がこのコピーからセッションを確立（再確立）します — pass-cli のセッションは数時間で失効するため、これによりエージェントはコンテナ再起動なしで復旧できます。セッションは `proton-pass` volume に永続化され rebuild を跨いで残ります。ホストに PAT ファイルが無ければ全ステップがスキップされ、コンテナは pass-cli のシークレットなしで通常どおり動きます。

PAT はコンテナ内に常駐するため、「コンテナの侵害 = PAT の侵害」と見なしてください。本当の境界はファイルの置き場所ではなく、下記の Proton 側のスコープ — 専用の最小権限 vault・有効期限・revoke — です。（エージェントがトークンの値を扱う必要は一切ありません: `AGENTS.md` の指示は `pass-relogin` の実行だけを指すため、値は会話ログ・エージェントのメモリ・モデルへの送信コンテキストに載りません。）

**スコープモデル:** PAT は専用 vault（例: `agent-secrets`）だけにスコープした `viewer` ロール・有効期限付きで発行してください。Proton のデフォルト 60 分はこの運用には短すぎます — 1〜2 週間程度で発行してローテーションします。その vault の中身はエージェントから読めます — 「vault に入れた = エージェントに渡した」と見なし、入れるトークン自体も最小権限にします（GitHub は fine-grained PAT など）。マスキングは衛生であって境界ではありません: サブプロセスはシークレットをファイルに書いたりネットワークに送ったりできます。

**プロジェクト別 vault（任意）:** このプロジェクト専用の被害半径にしたい場合は、専用 vault（例: `agents-<project>`）を作り、それだけにスコープした PAT を `~/.config/proton-pass-agent/<ディレクトリ名>` として保存します — `initialize.sh` が自動で拾い、無ければ共有ファイルにフォールバックするため、リポジトリ側の設定は不要です。PAT 名を vault 名と揃えると Proton の監査ログで「どのプロジェクトのエージェントのアクセスか」が判別できます。プロジェクトのリポジトリスコープ GitHub PAT は固定アイテム名 `github-fine-grained` でその vault に置き（`pass-relogin` が `gh` へ seed）、`.env` の参照はその vault のアイテム ID から作ってください。

**ホスト側セットアップ（初回のみ、bash が使える OS ならどれでも）:**

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; read -rs PAT; printf '%s' "$PAT" > ~/.config/proton-pass-agent/pat)
```

ローテーションは新しい PAT を発行後、ファイルを上書きしてコンテナを再起動してください。パスは dotfile 同期ツールやクラウドバックアップの対象外の場所を選びます。以前 macOS の Keychain に PAT を登録していた場合は、次のコマンドで移行できます:

```bash
mkdir -p ~/.config/proton-pass-agent
(umask 077; security find-generic-password -w -s proton-pass-agent-pat > ~/.config/proton-pass-agent/pat)
security delete-generic-password -s proton-pass-agent-pat
```

（プロジェクト別アイテムは `proton-pass-agent-pat-<ディレクトリ名>` → `~/.config/proton-pass-agent/<ディレクトリ名>` として繰り返してください。）

## node_modules と pnpm ストアの分離

`node_modules` にはプラットフォーム固有のネイティブバイナリ（biome / esbuild 等）が入るため、ホスト（例: macOS）とコンテナ（Linux）で同じディレクトリを共有すると、切り替えのたびに再インストールが必要になります。このテンプレートでは:

- **`node_modules`** — named volume（`node-modules`）が bind mount 上のホスト側 `node_modules` をコンテナ内でマスクします。ホスト側はホスト用、コンテナ側は volume 内の Linux 用がそのまま残り、双方の再インストールは不要になります。
- **pnpm ストア** — `post-create.sh` が `store-dir` を volume（`pnpm-store`、`~/.pnpm-store`）に固定します。未指定だと pnpm はプロジェクトと同じファイルシステムにストアを作るため、ホストの checkout 直下に `.pnpm-store/` が漏れてしまうのを防ぎます。volume なのでリビルド後もダウンロードキャッシュが残ります。

依存をやり直したいときはコンテナ内で `rm -rf node_modules && pnpm install` を実行してください（ホスト側には影響しません）。まっさらにしたい場合は `docker volume rm` で該当 volume を削除してからリビルドします。なお、ストア volume と `node_modules` volume は別マウントのため hardlink は効かず pnpm は自動的に copy にフォールバックします（正しさとキャッシュ維持を優先した割り切りです）。

## その他のメモ

- Feature の更新を取り込む: `devcontainer up --workspace-folder . --remove-existing-container`（VS Code なら「Rebuild Container」）。
- ホストの Docker ソケットは意図的にマウントしていません。エージェントはホストのコンテナを操作できません。
