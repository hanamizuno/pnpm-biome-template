# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.
ユーザーとの会話やドキュメント・コメント・コミットメッセージ・プルリクエストは日本語で書いてください。

## プロジェクト概要

Node.js + pnpm + Biomeベースのテンプレートプロジェクトです。TypeScriptを使用し、Biomeによるフォーマット・リント、vitestによるテストを標準構成としています。

## 開発コマンド

### 基本的なコマンド

```bash
# 開発サーバーの起動（ファイル変更を監視して自動再起動）
pnpm dev

# テスト実行
pnpm test

# テスト実行（カバレッジレポート付き）
pnpm test:cov

# コードフォーマット
pnpm fmt
# フォーマットチェックのみ（CIで使用）
pnpm biome format --check .

# リンター実行
pnpm lint

# フォーマット・リント一括チェック
pnpm biome check .

# 型チェック・フォーマット・リント一括実行
pnpm check

# ベンチマーク実行
pnpm bench

# リリース前チェック（フォーマット・リント・型チェック・テスト一括実行）
pnpm release-check

# シークレットスキャン（機密情報の検出）
pnpm scan:secrets

# 通常の実行
pnpm tsx src/main.ts
```

### pnpmコマンド

```bash
# 依存関係のインストール
pnpm install --frozen-lockfile

# 依存関係の追加
pnpm add <package-name>

# 開発依存関係の追加
pnpm add -D <package-name>

# 依存関係の更新
pnpm update
```

## アーキテクチャ概要

### ディレクトリ構造

```
.
├── src/
│   ├── main.ts              # エントリーポイント
│   ├── main.test.ts         # テストファイル
│   └── main.bench.ts        # ベンチマークファイル
├── package.json             # プロジェクト設定・依存関係
├── pnpm-lock.yaml           # 依存関係のロックファイル
├── tsconfig.json            # TypeScript設定
├── biome.json               # Biome（フォーマッター・リンター）設定
├── vitest.config.ts         # vitest設定
├── AGENTS.md                # AIエージェント用ガイドライン（本ファイル）
├── CLAUDE.md                # AGENTS.md へのシンボリックリンク
├── CHANGELOG.md             # 変更履歴
├── LICENSE                  # MITライセンス
├── README.md                # プロジェクト説明
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

### 設定ファイル

#### biome.json

プロジェクトのフォーマッター・リンター設定：

- **formatter**: 行幅100文字、インデント: スペース2つ
- **javascript.formatter**: セミコロンあり、ダブルクォート
- **linter**: 推奨ルール使用
- **organizeImports**: 有効

#### tsconfig.json

TypeScript設定：

- **target**: ES2023
- **module**: Node16
- **strict**: 有効
- **rootDir**: ./src
- **outDir**: ./dist

#### vitest.config.ts

テスト設定：

- **coverage.provider**: v8
- **coverage.reporter**: text, html

#### GitHub Actions

継続的インテグレーション：

- **lint.yml**: プッシュ/PR時のコード品質チェック（biome ci + tsc --noEmit）
- **test.yml**: プッシュ/PR時のテスト実行とカバレッジ計測（PRにカバレッジレポートをコメント）
- **lint_gha.yml**: Actions自体のセキュリティチェック
- **security.yml**: 依存関係のセキュリティ監査（毎日実行）
- **deps-update.yml**: 依存関係の自動更新（毎週月曜実行、PRを自動作成）
- **copilot-setup-steps.yml**: GitHub Copilot用の環境セットアップ

### 技術選択

- **Node.js v22**: LTSランタイム
- **pnpm**: 高速・効率的なパッケージマネージャー
- **Biome v2**: 高速なフォーマッター・リンター
- **vitest**: TypeScriptネイティブなテストランナー
- **tsx**: TypeScript実行エンジン
- **TypeScript**: 型安全性とより良い開発体験

#### pre-commit hooks

`.pre-commit-config.yaml` で定義されたフック：

- **biome-format**: コミット前にフォーマットチェック
- **biome-lint**: コミット前にリントチェック

セットアップ:
[prek をインストール](https://github.com/j178/prek?tab=readme-ov-file#installation)後、`prek install`
を実行

## 開発のベストプラクティス

1. **型安全性**: TypeScriptの型システムを最大限活用
2. **テストファースト**: 機能追加前にテストを書く
3. **小さなコミット**: 論理的な単位でコミット
4. **CI/CD**: GitHub Actionsで品質を保証
5. **ドキュメント**: コードの意図を明確に記述
