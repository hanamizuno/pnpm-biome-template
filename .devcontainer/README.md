# AI Agent Dev Container

Dev Container は AI コーディングエージェント（Claude Code / Codex 等）の実行環境も兼ねます。エージェントのツールチェーンは [Dev Container Features](https://containers.dev/implementors/features/) と post-create セットアップで Node.js + pnpm の開発環境に重ねて注入されるため、プロジェクト固有の `claude/` ディレクトリや compose オーバーライドは不要です。

## 同梱エージェントツール

| ツール | ソース |
|---|---|
| 共通ユーティリティ（非 root の `vscode` ユーザー、sudo、各種パッケージ） | `ghcr.io/devcontainers/features/common-utils` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code` |
| Codex CLI | `post-create.sh` が `npm install -g @openai/codex` でインストール |
| Codex プラグイン（Claude Code 用） | `post-create.sh` が `claude plugin install codex@openai-codex` でインストール。Claude Code から必要に応じて Codex に委譲できる（`codex-rescue` サブエージェント + `/codex` スキル） |
| Chrome DevTools MCP（見た目のデバッグ用） | リポジトリルートの `Dockerfile` の `devcontainer` ステージが headless Chromium + 日本語フォントを導入し、`post-create.sh` が `chrome-devtools-mcp` をインストールして Claude Code に登録（Codex には `codex-config.toml` で登録） |

各 Feature は再現性のため `devcontainer.json` で `sha256` digest 固定されています。Node.js / pnpm は本リポジトリの `Dockerfile` の `devcontainer` ステージで導入しています（言語ランタイムは Dockerfile 側、エージェントツールは Features / post-create 側、という方針）。別の エージェント CLI（Cursor 等）を追加したい場合は、上流の Feature、`./<feature-id>/` 配下のローカル Feature、もしくは `post-create.sh` への冪等なインストールステップのいずれかを追記してください。

## 初回セットアップ

1. **コンテナを起動** — VS Code の「Reopen in Container」、もしくはヘッドレスに `devcontainer up --workspace-folder .`
2. **認証**（devcontainer ID ごとに 1 回のみ。ホストから bind mount せず、名前付きボリュームに永続化）:
   - **Claude Code**: そのままエージェントを起動すれば、初回はインラインでログインフローが表示されます。`/login` を CLI 引数で渡さないこと — それはアクティブセッション用のスラッシュコマンドで、ホストシェルから使うとフローが二重に起動します。
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: エージェントを起動して ChatGPT でサインインするか、`OPENAI_API_KEY` を設定します（`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` は `remoteEnv` 経由でホストシェルから転送されます — ホスト側で一度設定すればコンテナ内に現れます）。初回のコンテナ作成時に `codex-config.toml` が永続化される `~/.codex/config.toml` ボリュームにコピーされます。同じ post-create ステップで Claude Code の `~/.claude` ボリュームに `codex@openai-codex` プラグインもインストールされるため、Claude Code がセッションごとの再インストールなしに Codex を呼び出せます（`codex-rescue` サブエージェント + `/codex` スキル）。
     ```bash
     devcontainer exec --workspace-folder . codex
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
   認証情報は `claude-config-${devcontainerId}` / `codex-config-${devcontainerId}` / `gh-config-${devcontainerId}` ボリュームに格納され、`--remove-existing-container` での再ビルド後も残ります。

## ホスト設定の継承

コンテナの作成/起動のたびに、`initialize.sh`（`initializeCommand`、ホスト側で実行）が選択されたホスト設定を `.devcontainer/` 配下の git-ignore されたファイルへステージングし、`post-start.sh` がコンテナ内へ反映します:

- **グローバル gitignore** — `core.excludesFile` → `~/.config/git/ignore`（XDG）→ `~/.gitignore` の順で解決し、シンボリックリンクを実体化（例: Nix / home-manager のターゲット）した上で `host-gitignore` としてステージングし、コンテナ内の `~/.config/git/ignore`（git の XDG デフォルト。`git config` には触れない）へコピーします。起動ごとに上書きされるため、ホストが常に正です。
- **Git identity** — `user.name` / `user.email` をホストのグローバル git config から読み取り（ファイルではなく値を読むため includes が解決され、credential helper などホスト専用設定は持ち込まれない）、`host-gituser` としてステージングし、起動ごとに `git config --global` でコンテナ内へ反映します。ホストで未設定のキーには触れません。
- **Claude Code の settings + statusline** — `~/.claude/settings.json` はホストのホームパスを `/home/vscode` に書き換えた上で（`statusLine` コマンド等が動き続けるように）ステージングし、コンテナ内の `~/.claude/settings.json` へ `jq` で **deep-merge** します（キー単位でホスト優先。コンテナ内でのプラグイン有効化などコンテナ専用キーは残る）。`~/.claude/statusline-command.sh` も併せてコピーします。認証・状態（`~/.claude.json`、`~/.claude/.credentials.json`）は意図的にステージング**しません** — 認証はコンテナスコープのボリュームに留まります。

ホスト側にファイルが存在しない場合、そのステップは no-op となりコンテナは通常どおり起動します。

ステージングされた `host-*` ファイル（`host-gitignore` / `host-gituser` / `host-claude/`）は個人設定を含む git-ignore されたローカル生成物です。`git clone` では持ち出されませんが、チェックアウトの単純なファイルコピー（`cp -r` や zip）には含まれるため、このテンプレートを git 外でコピーする場合は除外してください。

> **Windows ホスト:** `initializeCommand` はホスト上で bash スクリプトを実行するため、ネイティブ Windows では Git Bash / WSL が `PATH` 上に必要です — 無い場合は同期がスキップされますが、コンテナ自体は起動します。

## 見た目のデバッグ（Chrome DevTools MCP）

エージェントは [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 経由でコンテナ内の headless Chromium を操作し、`pnpm dev` で立てた開発サーバーの画面をスクリーンショット・コンソールログ・ネットワークリクエストで確認できます。「この画面のレイアウト崩れを直して」のような依頼に対して、エージェントが自分で描画結果を見ながら修正→確認のループを回せます。

- **Claude Code**: `post-create.sh` が `claude mcp add chrome-devtools` で登録します（`~/.claude` ボリュームに永続化）。既存コンテナにはリビルド（post-create 再実行）で反映されます。
- **Codex**: `codex-config.toml` の `[mcp_servers.chrome-devtools]` で登録します。初回作成時にのみボリュームへコピーされる設定のため、既存の `~/.codex/config.toml` には同セクションを手動で追記してください。

技術メモ:

- Chromium は Debian の `chromium` パッケージを使用します（Apple Silicon ホストの arm64 コンテナでも動作。Google Chrome 公式 deb は amd64 のみのため不採用）。日本語の描画用に `fonts-noto-cjk` を同梱しています。
- コンテナ内ではカーネルサンドボックスが使えないため、`--no-sandbox` を付与する `/usr/local/bin/chromium-no-sandbox` ラッパー経由で起動します。信頼できないサイトの閲覧には使わず、ローカル開発サーバーの確認用としてください（コンテナ自体が隔離境界、という本テンプレートの方針の範囲内です）。
- MCP は `--isolated`（一時プロファイル）+ `--headless` で起動するため、表示用ディスプレイは不要です。利用統計の外部送信は `--no-usage-statistics` で無効化しています（隔離モードとの整合のため）。

## 動作モード

- **デフォルト（egress 開放）** — 送信トラフィックは制限しません。ホストの認証情報は bind mount せず（Claude / Codex / `gh` の認証はコンテナスコープのボリュームに格納）、ホストの Docker ソケットも露出しません。`--dangerously-skip-permissions` に対する防御面は「非 root の `vscode` ユーザー」「ワークスペース限定マウント」「コンテナスコープの認証ボリューム」の 3 点です。Codex はコンテナスコープの設定に `approval_policy = "never"` と `sandbox_mode = "workspace-write"` が seed されるため、書き込みをワークスペースに限定しつつ承認待ちなしで動作します。
- **隔離モード（任意）** — より厳格なサンドボックスにしたい場合は、egress 不可の Docker ネットワークを作成しコンテナをそこに接続します:
  ```bash
  docker network create --internal agent-internal
  ```
  ローカルオーバーライド（例: `devcontainer.local.json`）に `"runArgs": ["--network=agent-internal"]` を追加します。完全に外向き通信が遮断されるため、切り替え前に依存（`pnpm install` 等）を解決しておき、エージェントが API アクセスを要する場合は別途プロキシサイドカーを用意してください。

## この隔離が担保しない範囲

コンテナは爆発半径を「ホストユーザーが触れるすべて」から「ワークスペース + コンテナスコープの認証ボリューム」まで圧縮しますが、あくまで Linux コンテナであり microVM ではありません。具体的に、このテンプレートは以下を提供**しません**:

- 独立したカーネル（コンテナエスケープにつながるカーネル脆弱性は封じ込められません）
- 細粒度のネットワーク allow/deny リスト（あるのは上記の `--network=internal` による二値の隔離モードのみ）
- エージェントセッション内から安全にコンテナをビルド・実行するためのネスト Docker デーモン（ホストの Docker ソケットは意図的にマウントしていません）

これらが必要な場合は、[Docker Sandbox](https://docs.docker.com/ai/sandboxes/)（microVM のカーネル境界、allow/deny ネットワーク、サンドボックスごとの Docker デーモン）のような、より保証の強いサンドボックス内でエージェントを動かし、この devcontainer は内側のワークスペースとして扱ってください。

**ホストの loopback へのアクセスは意図的に開けていません。** `host.docker.internal` はデフォルトでは追加しません — 開けると `0.0.0.0` にバインドされたホストのサービス（ローカル LLM サーバー、開発用 DB、デバッグダッシュボード）がすべてエージェントから見えてしまいます。どうしても必要な場合（例: ローカルホストの OpenAI 互換エンドポイントをエージェントに使わせる）は、プロジェクトのデフォルトではなくローカルオーバーライドとして追加してください:

```jsonc
// .devcontainer/devcontainer.local.json (ユーザーごとのオーバーライド。コミットしない)
{ "runArgs": ["--add-host=host.docker.internal:host-gateway"] }
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

## node_modules と pnpm ストアの分離

`node_modules` にはプラットフォーム固有のネイティブバイナリ（biome / esbuild 等）が入るため、ホスト（例: macOS）とコンテナ（Linux）で同じディレクトリを共有すると、切り替えのたびに再インストールが必要になります。このテンプレートでは:

- **`node_modules`** — named volume（`node-modules-${devcontainerId}`）が bind mount 上のホスト側 `node_modules` をコンテナ内でマスクします。ホスト側はホスト用、コンテナ側は volume 内の Linux 用がそのまま残り、双方の再インストールは不要になります。
- **pnpm ストア** — `post-create.sh` が `store-dir` を volume（`pnpm-store-${devcontainerId}`、`~/.pnpm-store`）に固定します。未指定だと pnpm はプロジェクトと同じファイルシステムにストアを作るため、ホストの checkout 直下に `.pnpm-store/` が漏れてしまうのを防ぎます。volume なのでリビルド後もダウンロードキャッシュが残ります。

依存をやり直したいときはコンテナ内で `rm -rf node_modules && pnpm install` を実行してください（ホスト側には影響しません）。まっさらにしたい場合は `docker volume rm` で該当 volume を削除してからリビルドします。なお、ストア volume と `node_modules` volume は別マウントのため hardlink は効かず pnpm は自動的に copy にフォールバックします（正しさとキャッシュ維持を優先した割り切りです）。

## その他のメモ

- Feature の更新を取り込む: `devcontainer up --workspace-folder . --remove-existing-container`（VS Code なら「Rebuild Container」）。
- ホストの Docker ソケットは意図的にマウントしていません。エージェントはホストのコンテナを操作できません。
