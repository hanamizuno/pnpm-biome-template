# Changelog

このプロジェクトに対するすべての重要な変更を記録します。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づいています。

## [Unreleased]

### Added

- `tsconfig.build.json` を分離（テスト/ベンチを除外したビルド用設定）
- `package.json` に `engines.node`、`packageManager`、`build`、`start`、`fmt:check` を追加
- `.editorconfig` / `.npmrc` / `.nvmrc` / `.secretlintignore` を追加
- `SECURITY.md` / `CODE_OF_CONDUCT.md` / `CONTRIBUTING.md` / `.github/CODEOWNERS` を追加
- pre-commit に `typecheck` と `secretlint` フックを追加
- CI (`lint.yml`) に `secretlint` ステップを追加
- `test.yml` に Node 24/25 のマトリクスを導入
- `copilot-setup-steps.yml` に `release-check` のスモークを追加
- すべての workflow に `concurrency` と `timeout-minutes` を設定

### Changed

- `tsconfig.json` を `nodenext` + `noUncheckedIndexedAccess` 等で厳格化、`types: ["node"]` を明示
- `src/main.ts` の脆いエントリ判定を `import.meta.main`（Node 24+）に置換
- `Dockerfile` を builder/prod に分離し、prod は `tsc` 成果物を非 root の `node` ユーザーで実行
- `compose.dev.yml` にソース bind mount と `node_modules` 上書き保護を追加
- `biome.json` で `vcs.useIgnoreFile` を有効化、`pnpm-lock.yaml` を対象外に
- `vitest.config.ts` にカバレッジしきい値 80%、`clearMocks`/`restoreMocks` を設定
- `deps-update.yml` を `--force-with-lease` 化、`dependabot.yml` を GitHub Actions のみに集約
- `test.yml` の PR コメント生成を null 安全化、`FORCE_COLOR=0`/`NO_COLOR=1` で ANSI を抑止
- `devcontainer.json` の Features を sha256 digest で固定
- 全 workflow の Node バージョン解決を `.nvmrc` に統一

### Fixed

- AGENTS.md / README.md の不整合（`ES2023` → `ES2025`、存在しない `agent/`、Biome v1 表記）を修正
- `package.json` の `scan:secrets` を `npx` から `pnpm exec` に変更（lockfile を尊重）
- `.gitignore` に `.claude/settings.local.json` を明示

### Removed

- `devcontainer.json` の冗長な `postStartCommand`
