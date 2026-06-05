# pnpm + Biome Template

シンプルな Node.js + pnpm + Biome プロジェクトのテンプレートです。

## 機能一覧

- TypeScript による型安全な開発環境
- Biome による高速なフォーマット・リント
- テスト・ベンチマーク・カバレッジ計測（vitest, しきい値 80%）
- pre-commit hooks による品質保証（biome / typecheck / secretlint）
- GitHub Actions による CI（Node 24/25 マトリクス、Actions と Features を sha256 固定、依存自動更新）
- シークレットスキャン（secretlint）
- VS Code Dev Containers: AI エージェントツールチェーン（Claude Code CLI、Codex CLI、Hermes Agent、GitHub CLI、共通ユーティリティ）を [Dev Container Features](https://containers.dev/implementors/features/) と post-create セットアップで重ねて注入
- Chrome DevTools MCP + headless Chromium: エージェントがコンテナ内で画面の見た目をデバッグ（スクリーンショット・コンソール・ネットワーク確認）

## セットアップ

```bash
corepack enable
pnpm install
```

`pnpm` は `package.json` の `packageManager` フィールド経由で corepack が自動的に正しいバージョンを使用します。

### pre-commit hooks（任意）

[prek](https://github.com/j178/prek) を[インストール](https://github.com/j178/prek?tab=readme-ov-file#installation)した後：

```bash
prek install
```

## 主なコマンド

```bash
pnpm dev            # tsx --watch で開発実行
pnpm test           # テスト
pnpm test:cov       # カバレッジ計測
pnpm bench          # ベンチマーク
pnpm fmt            # フォーマット適用
pnpm lint           # リント
pnpm check          # biome check + typecheck
pnpm release-check  # CI 相当の一括チェック（biome ci + typecheck + test）
pnpm scan:secrets   # シークレット検出
pnpm build          # tsc で dist/ に出力
pnpm start          # node dist/main.js
```

詳細は [AGENTS.md](AGENTS.md) を参照。

## プロジェクト構造

ディレクトリ構成・設定ファイルの詳細は [AGENTS.md](AGENTS.md) を参照してください。

## AI Agent Dev Container

Dev Container は AI コーディングエージェント（Claude Code / Codex / Hermes 等）の実行環境も兼ねます。エージェントのツールチェーンは [Dev Container Features](https://containers.dev/implementors/features/) と post-create セットアップで Node.js + pnpm の開発環境に重ねて注入されるため、プロジェクト固有の `claude/` ディレクトリや compose オーバーライドは不要です。

### 同梱エージェントツール

| ツール | ソース |
|---|---|
| 共通ユーティリティ（非 root の `vscode` ユーザー、sudo、各種パッケージ） | `ghcr.io/devcontainers/features/common-utils` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code` |
| Codex CLI | `.devcontainer/post-create.sh` が `npm install -g @openai/codex` でインストール |
| Codex プラグイン（Claude Code 用） | `.devcontainer/post-create.sh` が `claude plugin install codex@openai-codex` でインストール。Claude Code から必要に応じて Codex に委譲できる（`codex-rescue` サブエージェント + `/codex` スキル） |
| Hermes Agent | `.devcontainer/post-create.sh` が上流 `NousResearch/hermes-agent` のユーザー単位 `uv` インストーラーでインストール |
| Chrome DevTools MCP（見た目のデバッグ用） | `Dockerfile` の `devcontainer` ステージが headless Chromium + 日本語フォントを導入し、`.devcontainer/post-create.sh` が `chrome-devtools-mcp` をインストールして Claude Code に登録（Codex には `.devcontainer/codex-config.toml` で登録） |

各 Feature は再現性のため `.devcontainer/devcontainer.json` で `sha256` digest 固定されています。Node.js / pnpm は本リポジトリの `Dockerfile` の `devcontainer` ステージで導入しています（言語ランタイムは Dockerfile 側、エージェントツールは Features / post-create 側、という方針）。別の エージェント CLI（Cursor 等）を追加したい場合は、上流の Feature、`./.devcontainer/<feature-id>/` 配下のローカル Feature、もしくは `.devcontainer/post-create.sh` への冪等なインストールステップのいずれかを追記してください。

### 初回セットアップ

1. **コンテナを起動** — VS Code の「Reopen in Container」、もしくはヘッドレスに `devcontainer up --workspace-folder .`
2. **認証**（devcontainer ID ごとに 1 回のみ。ホストから bind mount せず、名前付きボリュームに永続化）:
   - **Claude Code**: そのままエージェントを起動すれば、初回はインラインでログインフローが表示されます。`/login` を CLI 引数で渡さないこと — それはアクティブセッション用のスラッシュコマンドで、ホストシェルから使うとフローが二重に起動します。
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
     ```
   - **Codex CLI**: エージェントを起動して ChatGPT でサインインするか、コンテナ内で `OPENAI_API_KEY` を設定します。初回のコンテナ作成時に `.devcontainer/codex-config.toml` が永続化される `~/.codex/config.toml` ボリュームにコピーされます。同じ post-create ステップで Claude Code の `~/.claude` ボリュームに `codex@openai-codex` プラグインもインストールされるため、Claude Code がセッションごとの再インストールなしに Codex を呼び出せます（`codex-rescue` サブエージェント + `/codex` スキル）。
     ```bash
     devcontainer exec --workspace-folder . codex
     ```
   - **Hermes Agent**: インストーラーはバイナリを配置するだけです。初回起動後に `hermes setup`（フルウィザード）または `hermes model`（プロバイダー/モデルのみ）で設定してください。主要な LLM プロバイダーの API キー（`OPENROUTER_API_KEY`、`OPENAI_API_KEY`、`ANTHROPIC_API_KEY`、`NOUS_PORTAL_API_KEY`）は `remoteEnv` 経由でホストシェルから転送されます — ホスト側で一度設定すればコンテナ内に現れます。初回のコンテナ作成時に `.devcontainer/hermes-config.yaml` が永続化される `~/.hermes/config.yaml` ボリュームにコピーされます（承認は無効化 — コンテナが隔離境界）。
     ```bash
     devcontainer exec --workspace-folder . hermes
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
   認証情報は `claude-config-${devcontainerId}` / `codex-config-${devcontainerId}` / `hermes-config-${devcontainerId}` / `gh-config-${devcontainerId}` ボリュームに格納され、`--remove-existing-container` での再ビルド後も残ります。

### 見た目のデバッグ（Chrome DevTools MCP）

エージェントは [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 経由でコンテナ内の headless Chromium を操作し、`pnpm dev` で立てた開発サーバーの画面をスクリーンショット・コンソールログ・ネットワークリクエストで確認できます。「この画面のレイアウト崩れを直して」のような依頼に対して、エージェントが自分で描画結果を見ながら修正→確認のループを回せます。

- **Claude Code**: `post-create.sh` が `claude mcp add chrome-devtools` で登録します（`~/.claude` ボリュームに永続化）。既存コンテナにはリビルド（post-create 再実行）で反映されます。
- **Codex**: `.devcontainer/codex-config.toml` の `[mcp_servers.chrome-devtools]` で登録します。初回作成時にのみボリュームへコピーされる設定のため、既存の `~/.codex/config.toml` には同セクションを手動で追記してください。
- **Hermes**: MCP 連携は未設定です（必要なら `~/.hermes/config.yaml` で各自設定）。

技術メモ:

- Chromium は Debian の `chromium` パッケージを使用します（Apple Silicon ホストの arm64 コンテナでも動作。Google Chrome 公式 deb は amd64 のみのため不採用）。日本語の描画用に `fonts-noto-cjk` を同梱しています。
- コンテナ内ではカーネルサンドボックスが使えないため、`--no-sandbox` を付与する `/usr/local/bin/chromium-no-sandbox` ラッパー経由で起動します。信頼できないサイトの閲覧には使わず、ローカル開発サーバーの確認用としてください（コンテナ自体が隔離境界、という本テンプレートの方針の範囲内です）。
- MCP は `--isolated`（一時プロファイル）+ `--headless` で起動するため、表示用ディスプレイは不要です。利用統計の外部送信は `--no-usage-statistics` で無効化しています（隔離モードとの整合のため）。

### 動作モード

- **デフォルト（egress 開放）** — 送信トラフィックは制限しません。ホストの認証情報は bind mount せず（Claude / Codex / `gh` の認証はコンテナスコープのボリュームに格納）、ホストの Docker ソケットも露出しません。`--dangerously-skip-permissions` に対する防御面は「非 root の `vscode` ユーザー」「ワークスペース限定マウント」「コンテナスコープの認証ボリューム」の 3 点です。Codex はコンテナスコープの設定に `approval_policy = "never"` と `sandbox_mode = "workspace-write"` が seed されるため、書き込みをワークスペースに限定しつつ承認待ちなしで動作します。
- **隔離モード（任意）** — より厳格なサンドボックスにしたい場合は、egress 不可の Docker ネットワークを作成しコンテナをそこに接続します:
  ```bash
  docker network create --internal agent-internal
  ```
  ローカルオーバーライド（例: `.devcontainer/devcontainer.local.json`）に `"runArgs": ["--network=agent-internal"]` を追加します。完全に外向き通信が遮断されるため、切り替え前に依存（`pnpm install` 等）を解決しておき、エージェントが API アクセスを要する場合は別途プロキシサイドカーを用意してください。

### GitHub 権限の制限（PAT）

Claude Code を `--dangerously-skip-permissions` で動かすと、保存された `gh` トークンのスコープをそのまま引き継ぎます。爆発半径を絞るため、普段使いの `$GH_TOKEN` ではなく専用 PAT をボリュームに seed することを推奨します。

**手順:**

1. GitHub で PAT を発行:
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
| リポジトリ作成 / 設定変更 | `+ Administration: Write`（organization では承認要の場合あり） |

**注意 / ハマりどころ:**

- Fine-grained PAT は `gh` の一部サブコマンドにまだ未対応です。403 や「PAT not supported」が返るときは最小スコープの Classic PAT にフォールバックしてください。
- トークンはボリューム内の `~/.config/gh/hosts.yml` に格納されます。コンテナ内でシェルが取れる人物は値を読めるため、コンテナの侵害＝トークンのスコープ範囲が侵害された、と見なしてください。
- ローテーションは手順 2 + 3 の繰り返しで OK（ボリュームを作り直す必要はありません）。

### その他のメモ

- Feature の更新を取り込む: `devcontainer up --workspace-folder . --remove-existing-container`（VS Code なら「Rebuild Container」）。
- ホストの Docker ソケットは意図的にマウントしていません。エージェントはホストのコンテナを操作できません。

## コントリビューション

[CONTRIBUTING.md](CONTRIBUTING.md) と [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) を参照してください。脆弱性報告は [SECURITY.md](SECURITY.md) の手順に従ってください。

## リリースチェックリスト

1. `pnpm release-check` を実行してすべてのチェックが通ることを確認
2. `CHANGELOG.md` を更新
3. バージョンタグを作成

## ライセンス

[MIT](LICENSE)
