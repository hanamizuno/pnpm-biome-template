# Changelog

このプロジェクトに対するすべての重要な変更を記録します。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づいています。

## [Unreleased]

### Added

- Dev Container に Chrome DevTools MCP + headless Chromium を追加（エージェントによる画面の見た目デバッグ用。`--no-sandbox` ラッパー経由で起動、日本語フォント同梱、Claude Code / Codex に登録）
- Dev Container のホスト設定継承（グローバル gitignore / git identity / Claude Code の settings・statusline を `initialize.sh` でステージングし `post-start.sh` で反映）
- `docs/knowledge/` を OKF v0.1 の知識バンドル（architecture / adr / conventions / runbooks / research のスケルトン）として追加
- GitHub ラベルを `.github/labels.yml` から同期するワークフローを追加（`deps-update.yml` が使う `dependencies` ラベルも定義）
- Dockerfile リント（hadolint、`lint_docker.yml`）と GitHub Actions リント（actionlint）を追加
- Trivy による filesystem スキャンを `security.yml` に追加（PR では table 出力で fail、push/cron では SARIF を Security タブへ）
- CycloneDX SBOM 生成ワークフロー（`sbom.yml`、cdxgen）を追加
- Issue テンプレートを YAML issue forms へ移行し、`config.yml` で blank issue を無効化
- `tsconfig.build.json` を分離（テスト/ベンチを除外したビルド用設定）
- `package.json` に `engines.node`、`packageManager`、`build`、`start`、`fmt:check` を追加
- `.editorconfig` / `.npmrc` / `.nvmrc` / `.secretlintignore` / `.gitattributes` / `.github/CODEOWNERS` を追加
- pre-commit に `typecheck` と `secretlint` フックを追加
- CI (`lint.yml`) に `secretlint` ステップを追加
- `test.yml` に Node 24/25 のマトリクスを導入
- `copilot-setup-steps.yml` に `release-check` のスモークを追加
- `.github/copilot-instructions.md` に AGENTS.md への参照と主要コマンドを追記

### Changed

- `tsconfig.json` を `nodenext` + `noUncheckedIndexedAccess` 等で厳格化、`types: ["node"]` を明示
- `src/main.ts` の脆いエントリ判定を `import.meta.main`（Node 24+）に置換
- `Dockerfile` を builder/prod に分離し、prod は `tsc` 成果物を非 root の `node` ユーザーで実行
- `Dockerfile` のベースイメージ（`node:24-slim` / devcontainers base）を sha256 digest で固定
- `devcontainer.json` の Features を sha256 digest で固定
- `compose.dev.yml` にソース bind mount と `node_modules` 上書き保護を追加
- `biome.json` で `vcs.useIgnoreFile` を有効化、`pnpm-lock.yaml` を対象外に
- `vitest.config.ts` にカバレッジしきい値 80%、`clearMocks`/`restoreMocks`、`lcov` レポーターを設定
- `dependabot.yml` に `docker` / `devcontainers` エコシステムと 7 日間の cooldown を追加（npm は `deps-update.yml` が担当）
- `deps-update.yml` を `--force-with-lease` 化し、PR 作成前の検証を `pnpm test` から `pnpm release-check` に強化
- `test.yml` の PR コメント生成を null 安全化、`FORCE_COLOR=0`/`NO_COLOR=1` で ANSI を抑止、fork からの PR ではコメントをスキップ
- 全 workflow の Node バージョン解決を `.nvmrc` に統一
- 全 workflow を top-level `permissions: {}` + job 単位の最小権限に統一し、`concurrency`（PR のみ cancel、ミューテーション系は直列化）と `timeout-minutes` を設定
- `lint_gha.yml` の zizmor をバージョン固定（`uvx zizmor@1.26.1`）し、`.zizmor.yml` のポリシーを全アクション `hash-pin` に強化
- `packageManager` を integrity ハッシュ付きで `pnpm@11.9.0` に固定
- `@types/node` を最低サポートランタイム（Node 24）に合わせて `^24` に変更
- `LICENSE` の年・著作権者をプレースホルダ化（派生先で置換する前提）

### Fixed

- AGENTS.md / README.md の不整合（`ES2023` → `ES2025`、存在しない `agent/`、Biome v1 表記、pre-commit フック名、古いディレクトリ構造）を修正
- `package.json` の `scan:secrets` を `npx` から `pnpm exec` に変更（lockfile を尊重）
- `.gitignore` に `.claude/settings.local.json` を明示
- `.dockerignore` に `.pnpm-store` / `docs` を追加（ビルドコンテキストの肥大を解消）
- Dev Container の `node_modules` と pnpm ストアを named volume でホストと分離（プラットフォーム固有バイナリの混在による再インストールループと、ホスト checkout への `.pnpm-store` 漏れを解消）

### Removed

- `devcontainer.json` の冗長な `postStartCommand`
- コントリビュート系ドキュメント（`SECURITY.md` / `CODE_OF_CONDUCT.md` / `CONTRIBUTING.md`）はテンプレートに含めない方針に変更
