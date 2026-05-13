# pnpm + Biome Template

シンプルなNode.js + pnpm + Biomeプロジェクトのテンプレートです。

## 機能一覧

- TypeScript によるセキュアな開発環境
- Biome による高速なフォーマット・リント
- テスト・ベンチマークの実行基盤（vitest）
- カバレッジレポート付きテスト
- pre-commit hooks による品質保証
- GitHub Actions による CI/CD
- シークレットスキャンによる機密情報漏洩防止
- 依存関係の自動更新
- VS Code Dev Containers: `.devcontainer/devcontainer.json` で AI エージェントツールチェーン（Claude Code CLI、GitHub CLI、共通ユーティリティ）を [Dev Container Features](https://containers.dev/implementors/features/) としてプロジェクト環境に重ねて注入。専用 Dockerfile やオーバーライドは不要。

## セットアップ

[Node.js](https://nodejs.org/) をインストールし、[corepack](https://nodejs.org/api/corepack.html) で pnpm を有効化してください。

```bash
corepack enable
pnpm install
```

### pre-commit hooks の設定（任意）

[prek](https://github.com/j178/prek)
を[インストール](https://github.com/j178/prek?tab=readme-ov-file#installation)した後：

```bash
prek install
```

## 使い方

```bash
# 開発サーバーの起動
pnpm dev

# テストの実行
pnpm test

# テスト実行（カバレッジレポート付き）
pnpm test:cov

# ベンチマークの実行
pnpm bench

# コードのフォーマット
pnpm fmt

# リントの実行
pnpm lint

# 型チェック・フォーマット・リント一括実行
pnpm check

# リリース前チェック（フォーマット・リント・型チェック・テスト）
pnpm release-check

# シークレットスキャン
pnpm scan:secrets
```

## プロジェクト構造

```
.
├── src/
│   ├── main.ts              # エントリーポイント
│   ├── main.test.ts         # テストファイル
│   └── main.bench.ts        # ベンチマークファイル
├── package.json             # プロジェクト設定・依存関係
├── pnpm-lock.yaml           # 依存関係のロックファイル
├── tsconfig.json            # TypeScript設定
├── biome.json               # Biome設定
├── vitest.config.ts         # vitest設定
├── AGENTS.md                # AIエージェント用ガイドライン
├── CLAUDE.md                # AGENTS.md へのシンボリックリンク
├── CHANGELOG.md             # 変更履歴
├── LICENSE                  # MITライセンス
├── README.md                # プロジェクト説明（本ファイル）
├── .pre-commit-config.yaml  # pre-commit hooks設定
├── .secretlintrc.json       # secretlint設定
├── .zizmor.yml              # GitHub Actionsセキュリティ設定
├── .github/
│   └── workflows/           # GitHub Actions CI/CD
│       ├── lint.yml          # リンターとフォーマットチェック
│       ├── test.yml          # テスト実行
│       ├── lint_gha.yml      # GitHub Actions自体のリント
│       ├── security.yml      # 依存関係のセキュリティ監査
│       ├── deps-update.yml   # 依存関係の自動更新
│       └── copilot-setup-steps.yml # GitHub Copilot環境セットアップ
└── agent/                   # エージェント用ドキュメント保存ディレクトリ
```

## AI Agent Dev Container

Dev Container は AI コーディングエージェント（Claude Code 等）の実行環境も兼ねます。エージェントのツールチェーンは [Dev Container Features](https://containers.dev/implementors/features/) として Node.js + pnpm の開発環境に重ねて注入されるため、プロジェクト固有の `claude/` ディレクトリや compose オーバーライドは不要です。

### 同梱 Features

| Feature | ソース |
|---|---|
| 共通ユーティリティ（非 root の `vscode` ユーザー、sudo、各種パッケージ） | `ghcr.io/devcontainers/features/common-utils:2` |
| GitHub CLI | `ghcr.io/devcontainers/features/github-cli:1` |
| Claude Code CLI | `ghcr.io/anthropics/devcontainer-features/claude-code:1` |

Node.js / pnpm は本リポジトリの `Dockerfile` の `devcontainer` ステージで導入しています（言語ランタイムは Dockerfile 側、エージェントツールは Features 側、という方針）。別の エージェント CLI（Codex / Cursor 等）を追加したい場合は、上流の Feature か、`./.devcontainer/<feature-id>/` 配下のローカル Feature を `devcontainer.json` の `features` に追記してください。

### 初回セットアップ

1. **コンテナを起動** — VS Code の「Reopen in Container」、もしくはヘッドレスに `devcontainer up --workspace-folder .`
2. **認証**（devcontainer ID ごとに 1 回のみ。ホストから bind mount せず、名前付きボリュームに永続化）:
   - **Claude Code**: そのままエージェントを起動すれば、初回はインラインでログインフローが表示されます。`/login` を CLI 引数で渡さないこと — それはアクティブセッション用のスラッシュコマンドで、ホストシェルから使うとフローが二重に起動します。
     ```bash
     devcontainer exec --workspace-folder . claude --dangerously-skip-permissions
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
   認証情報は `claude-config-${devcontainerId}` / `gh-config-${devcontainerId}` ボリュームに格納され、`--remove-existing-container` での再ビルド後も残ります。

### 動作モード

- **デフォルト（egress 開放）** — 送信トラフィックは制限しません。ホストの認証情報は bind mount せず（Claude / `gh` の認証はコンテナスコープのボリュームに格納）、ホストの Docker ソケットも露出しません。`--dangerously-skip-permissions` に対する防御面は「非 root の `vscode` ユーザー」「ワークスペース限定マウント」「コンテナスコープの認証ボリューム」の 3 点です。
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

## リリースチェックリスト

1. `pnpm release-check` を実行してすべてのチェックが通ることを確認
2. `CHANGELOG.md` を更新
3. バージョンタグを作成

## ライセンス

[MIT](LICENSE)
