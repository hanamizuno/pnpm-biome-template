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

## Claude Code Container

`--dangerously-skip-permissions` で Claude Code を自律実行するための隔離コンテナ。

- **ネットワークファイアウォール:** iptables による送信トラフィック制御
- **非 root ユーザー:** `claude`（UID 1000）で実行
- **Docker ソケットなし:** ホスト Docker にアクセス不可
- **ワークスペース隔離:** プロジェクトディレクトリのみマウント

### ファイアウォールモード

| モード | 説明 | ユースケース |
|---|---|---|
| `strict`（デフォルト） | 許可リストのみ（GitHub, npm, Anthropic API, GCS） | 実装、テスト、リファクタリング |
| `open` | 全送信 HTTPS/HTTP を許可 | Web 検索が必要なタスク |

### ホスト連携

- **Git author 情報:** 起動スクリプト（`scripts/claude-start.sh`）がホストの `git config` から `user.name` / `user.email` を読み取り、環境変数で渡します。標準・XDG・Nix/home-manager どのレイアウトでも動作します。
- **SSH・GitHub CLI 認証（opt-in）:** オーバーライドファイル `compose.claude.auth.yml` を追加すると `~/.ssh` と `~/.config/gh` を read-only マウントします。SSH 経由の `git push`/`pull` や `gh` CLI 操作（PR 作成、Issue 管理等）に必要です。

### 起動方法

```bash
# 起動（strict ファイアウォール）
scripts/claude-start.sh up -d

# 起動（HTTPS open）
FIREWALL_MODE=open scripts/claude-start.sh up -d

# SSH・GitHub CLI 認証付きで起動
scripts/claude-start.sh -f compose.claude.auth.yml up -d

# Claude Code を実行
docker compose -f compose.claude.yml exec claude claude --dangerously-skip-permissions

# 停止
docker compose -f compose.claude.yml down
```

## リリースチェックリスト

1. `pnpm release-check` を実行してすべてのチェックが通ることを確認
2. `CHANGELOG.md` を更新
3. バージョンタグを作成

## ライセンス

[MIT](LICENSE)
