# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.
ユーザーとの会話やドキュメント・コメント・コミットメッセージ・プルリクエストは日本語で書いてください。

## プロジェクト概要

Node.js + pnpm + Biomeベースのテンプレートプロジェクトです。TypeScriptを使用し、Biomeによるフォーマット・リント、vitestによるテストを標準構成としています。

コンテナ構成: `Dockerfile`（マルチステージ: `dev` / `prod` / `devcontainer`）、`compose.dev.yml`（開発）、`compose.yml`（本番）。Dev Container（`.devcontainer/devcontainer.json`）は AI エージェント CLI（Claude Code / Codex / GitHub CLI）を Dev Container Features と post-create フック経由で重ねて注入する実行環境も兼ねます。見た目のデバッグ用に headless Chromium + Chrome DevTools MCP（`chrome-devtools-mcp`）も同梱しており、エージェントが開発サーバーの画面をスクリーンショット等で確認できます。さらにホスト設定 — グローバル gitignore と Claude Code の settings / statusline — も継承します（`.devcontainer/initialize.sh` がステージングし、`.devcontainer/post-start.sh` がコンテナ内へ反映）。

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
pnpm fmt:check

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

# ビルド（tsc）
pnpm build

# ビルド成果物を実行
pnpm start

# 開発実行（tsx で TS を直接実行）
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
├── pnpm-workspace.yaml      # pnpm 設定（allowBuilds 等）
├── tsconfig.json            # TypeScript設定（型チェック用、テスト/ベンチ込み）
├── tsconfig.build.json      # ビルド用設定（テスト/ベンチを除外）
├── biome.json               # Biome（フォーマッター・リンター）設定
├── vitest.config.ts         # vitest設定
├── AGENTS.md                # AIエージェント用ガイドライン（本ファイル）
├── CLAUDE.md                # AGENTS.md へのシンボリックリンク
├── CHANGELOG.md             # 変更履歴
├── LICENSE                  # MITライセンス
├── README.md                # プロジェクト説明
├── .editorconfig            # エディタ共通設定
├── .npmrc                   # pnpm 挙動設定（engine-strict 等）
├── .nvmrc                   # Node.js バージョン固定
├── .pre-commit-config.yaml  # pre-commit hooks設定
├── .secretlintrc.json       # secretlint設定
├── .secretlintignore        # secretlint 除外パターン
├── .zizmor.yml              # GitHub Actionsセキュリティ設定
├── Dockerfile               # マルチステージ（dev / builder / prod / devcontainer）
├── compose.yml              # 本番用 Docker Compose
├── compose.dev.yml          # 開発用 Docker Compose
├── .devcontainer/
│   ├── devcontainer.json    # Dev Container 設定（AI エージェントツールも Features で注入）
│   ├── initialize.sh        # initialize フック（ホスト側で実行。グローバル gitignore / Claude Code 設定をステージング）
│   ├── post-create.sh       # post-create フック（pnpm install + Codex / Chrome DevTools MCP のセットアップ）
│   ├── post-start.sh        # post-start フック（ステージングされたホスト設定をコンテナ内へ反映）
│   └── codex-config.toml    # Codex CLI 初期設定（永続化される ~/.codex ボリュームへコピー、MCP 登録含む）
└── .github/
    ├── dependabot.yml       # GitHub Actions の自動更新
    └── workflows/           # GitHub Actions CI/CD
        ├── lint.yml          # リンターとフォーマットチェック + secretlint
        ├── test.yml          # テスト実行
        ├── lint_gha.yml      # GitHub Actions自体のリント
        ├── security.yml      # 依存関係のセキュリティ監査
        ├── deps-update.yml   # 依存関係の自動更新
        └── copilot-setup-steps.yml # GitHub Copilot環境セットアップ
```

### 設定ファイル

#### biome.json

プロジェクトのフォーマッター・リンター設定（Biome v2）：

- **vcs**: git 連携、`.gitignore` を尊重
- **formatter**: 行幅100文字、インデント: スペース2つ
- **javascript.formatter**: セミコロンあり、ダブルクォート
- **linter**: 推奨ルール使用
- **assist.actions.source.organizeImports**: 有効（v2 のパス）

#### tsconfig.json

TypeScript設定：

- **target**: ES2025
- **module / moduleResolution**: nodenext
- **lib**: ES2025
- **strict** に加え `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
  `isolatedModules`, `verbatimModuleSyntax` などを有効化
- **rootDir**: ./src
- **outDir**: ./dist

ビルド用には `tsconfig.build.json` がテスト/ベンチを除外して継承する。

#### vitest.config.ts

テスト設定：

- **include**: `src/**/*.test.ts`、**benchmark.include**: `src/**/*.bench.ts`
- **clearMocks / restoreMocks**: 有効
- **coverage.provider**: v8 / **reporter**: text, html / 80% しきい値

#### GitHub Actions

継続的インテグレーション：

- **lint.yml**: プッシュ/PR時のコード品質チェック（biome ci + tsc --noEmit）
- **test.yml**: プッシュ/PR時のテスト実行とカバレッジ計測（PRにカバレッジレポートをコメント）
- **lint_gha.yml**: Actions自体のセキュリティチェック
- **security.yml**: 依存関係のセキュリティ監査（毎日実行）
- **deps-update.yml**: 依存関係の自動更新（毎週月曜実行、PRを自動作成）
- **copilot-setup-steps.yml**: GitHub Copilot用の環境セットアップ

### 技術選択

- **Node.js v24**: LTSランタイム
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
