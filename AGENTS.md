# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.
ユーザーとの会話やドキュメント・コメント・コミットメッセージ・プルリクエストは日本語で書いてください。

## プロジェクト概要

Node.js + pnpm + Biomeベースのテンプレートプロジェクトです。TypeScriptを使用し、Biomeによるフォーマット・リント、vitestによるテストを標準構成としています。

コンテナ構成: `Dockerfile`（マルチステージ: `dev` / `prod` / `devcontainer`）、`compose.dev.yml`（開発）、`compose.yml`（本番）。Dev Container は Docker Compose ベース（`.devcontainer/compose.yaml` + `devcontainer.json`。gitignore 済み `compose.local.yaml` で個人環境向けオーバーライド可）で、AI エージェント CLI（Claude Code / Codex / GitHub CLI）を Dev Container Features と post-create フック経由で重ねて注入する実行環境も兼ねます。見た目のデバッグ用に headless Chromium + Chrome DevTools MCP（`chrome-devtools-mcp`）も同梱しており、エージェントが開発サーバーの画面をスクリーンショット等で確認できます。さらにホスト設定 — グローバル gitignore、git identity（user.name / user.email）、Claude Code の settings / statusline — も継承します（`.devcontainer/initialize.sh` がステージングし、`.devcontainer/post-start.sh` がコンテナ内へ反映）。

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
├── docs/
│   └── knowledge/           # OKF v0.1 知識バンドル（architecture / adr / conventions / runbooks / research）
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
├── .gitattributes           # 改行コードの統一（LF）
├── .npmrc                   # pnpm 挙動設定（engine-strict 等）
├── .nvmrc                   # Node.js バージョン固定
├── .pre-commit-config.yaml  # pre-commit hooks設定
├── .secretlintrc.json       # secretlint設定
├── .secretlintignore        # secretlint 除外パターン
├── .zizmor.yml              # GitHub Actionsセキュリティ設定（hash-pin ポリシー）
├── .dockerignore            # Docker ビルドコンテキストの除外
├── Dockerfile               # マルチステージ（dev / builder / prod / devcontainer）、ベースイメージ digest 固定
├── compose.yml              # 本番用 Docker Compose
├── compose.dev.yml          # 開発用 Docker Compose
├── .vscode/                 # VS Code 設定（biome を既定フォーマッタに、保存時に fixAll）
├── .devcontainer/
│   ├── devcontainer.json    # Dev Container 設定（compose.yaml を参照。AI エージェントツールは Features で注入）
│   ├── compose.yaml         # devcontainer 用 compose 定義（固定名 volume で認証永続化・node_modules 分離。compose.local.yaml でローカルオーバーライド）
│   ├── initialize.sh        # initialize フック（ホスト側で実行。compose.local.yaml スタブ生成 + グローバル gitignore / git identity / Claude Code 設定をステージング）
│   ├── post-create.sh       # post-create フック（pnpm install + Codex / Chrome DevTools MCP のセットアップ）
│   ├── post-start.sh        # post-start フック（ステージングされたホスト設定をコンテナ内へ反映）
│   └── codex-config.toml    # Codex CLI 初期設定（永続化される ~/.codex ボリュームへコピー、MCP 登録含む）
└── .github/
    ├── dependabot.yml       # GitHub Actions / Docker / Dev Container の自動更新（7 日 cooldown）
    ├── labeler.yml          # PR 自動ラベリングのパス定義（label_pr.yml が使用）
    ├── labels.yml           # リポジトリラベルの source of truth
    ├── CODEOWNERS           # コードオーナー（プレースホルダ）
    ├── copilot-instructions.md  # GitHub Copilot 向けガイド（AGENTS.md へのポインタ）
    ├── PULL_REQUEST_TEMPLATE.md # PR テンプレート
    ├── ISSUE_TEMPLATE/      # Issue forms（bug / enhancement / task、blank issue 無効）
    ├── scripts/
    │   └── sync-labels.sh   # ラベル同期スクリプト（labels.yml → GitHub）
    └── workflows/           # GitHub Actions CI/CD
        ├── lint.yml          # リンターとフォーマットチェック + secretlint
        ├── test.yml          # テスト実行
        ├── lint_gha.yml      # GitHub Actions自体のリント（actionlint + zizmor）
        ├── lint_docker.yml   # Dockerfile のリント（hadolint）
        ├── security.yml      # セキュリティ監査（pnpm audit + Trivy）
        ├── sbom.yml          # CycloneDX SBOM 生成
        ├── deps-update.yml   # 依存関係の自動更新
        ├── label_pr.yml      # PR 自動ラベリング（actions/labeler）
        ├── labels.yml        # ラベル同期
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
- **coverage.provider**: v8 / **reporter**: text, html, lcov / 80% しきい値

#### GitHub Actions

継続的インテグレーション：

- **lint.yml**: プッシュ/PR時のコード品質チェック（biome ci + tsc --noEmit + secretlint）
- **test.yml**: プッシュ/PR時のテスト実行とカバレッジ計測（PRにカバレッジレポートをコメント。fork からの PR はコメントをスキップ）
- **lint_gha.yml**: Actions 自体のリント（actionlint）とセキュリティチェック（zizmor、バージョン固定）
- **lint_docker.yml**: Dockerfile のリント（hadolint）
- **security.yml**: セキュリティ監査（毎日実行。pnpm audit + Trivy、push/cron 時は SARIF を Security タブへ）
- **sbom.yml**: CycloneDX SBOM の生成（依存関係の変更時、cdxgen）
- **deps-update.yml**: 依存関係の自動更新（毎週月曜実行、PRを自動作成）
- **labels.yml**: `.github/labels.yml` から GitHub ラベルを同期
- **label_pr.yml**: 変更パスに応じて PR に `meta` ラベルを自動付与（actions/labeler、sync-labels 有効。fork からの PR はスキップ）
- **copilot-setup-steps.yml**: GitHub Copilot用の環境セットアップ

共通規約: 全 workflow で top-level `permissions: {}` + job 単位の最小権限、`concurrency`（push/PR 系は PR のみ cancel、ミューテーション系は直列化）、`timeout-minutes`、アクションの commit SHA 固定（`.zizmor.yml` の `hash-pin` ポリシーで強制）。

### 技術選択

- **Node.js v24**: LTSランタイム
- **pnpm**: 高速・効率的なパッケージマネージャー
- **Biome v2**: 高速なフォーマッター・リンター
- **vitest**: TypeScriptネイティブなテストランナー
- **tsx**: TypeScript実行エンジン
- **TypeScript 7**: Go 製ネイティブコンパイラによる高速な型チェックと型安全性

#### pre-commit hooks

`.pre-commit-config.yaml` で定義されたフック：

- **biome-check**: コミット前にフォーマット・リントチェック（staged ファイル対象）
- **typecheck**: コミット前に型チェック（プロジェクト全体）
- **secretlint**: コミット前にシークレット検出（staged ファイル対象）

セットアップ:
[prek をインストール](https://github.com/j178/prek?tab=readme-ov-file#installation)後、`prek install`
を実行

## 開発のベストプラクティス

1. **型安全性**: TypeScriptの型システムを最大限活用
2. **テストファースト**: 機能追加前にテストを書く
3. **小さなコミット**: 論理的な単位でコミット
4. **CI/CD**: GitHub Actionsで品質を保証
5. **ドキュメント**: コードの意図を明確に記述

## シークレットの扱い（Proton Pass / pass-cli）

- シークレットをコミットしないこと。タスク用シークレット（API キー、トークン）は ambient な環境変数ではなく Proton Pass（`pass-cli`）から取得する。必要なコマンドは `PROTON_PASS_AGENT_REASON="<取得理由>" pass-cli run --env-file .env -- <cmd>` で実行する（`.env` には `pass://` 参照だけを書く。`example.env` からコピー）。
- `pass-cli` が認証エラーを返したとき、またはセッションが無いとき（`pass-cli info` が失敗するとき）は `.devcontainer/pass-relogin` を実行してからリトライする。コンテナ内に配備済みのトークンからセッションを復元し、`gh` 認証が無ければ seed もする。
- `~/.local/state/proton-pass-agent/pat` を読む・表示する・コピーすることは禁止 — トークンの値を扱う必要は一切なく、`pass-relogin` がすべて処理する。
