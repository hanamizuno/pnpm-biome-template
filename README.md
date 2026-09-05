# pnpm + Biome Template

Node.js + pnpm + Biome の TypeScript プロジェクトテンプレート。

## 機能

- TypeScript / Biome（フォーマット・リント）/ vitest（テスト・ベンチ・カバレッジ 80%）
- pre-commit hooks（biome / typecheck / secretlint）
- GitHub Actions CI: Node 24・25 マトリクス、依存自動更新、PR 自動ラベリング、アクションと Docker ベースイメージの digest 固定
- セキュリティ: secretlint / pnpm audit / Trivy（SARIF を Security タブへ）、CycloneDX SBOM、hadolint / actionlint / zizmor
- AI エージェント実行環境: Dev Container（Claude Code / Codex / OpenCode / Pi + Chrome DevTools MCP）と [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) 用 kit（`.sandbox/`）

## セットアップ

```bash
corepack enable
pnpm install
```

pnpm のバージョンは `package.json` の `packageManager` から corepack が解決する。pre-commit hooks を使う場合は [prek](https://github.com/j178/prek) をインストールして `prek install`。

## 主なコマンド

```bash
pnpm dev            # tsx --watch で開発実行
pnpm test           # テスト（test:cov でカバレッジ、bench でベンチマーク）
pnpm fmt            # フォーマット適用（lint でリント、check で biome check + typecheck）
pnpm release-check  # CI 相当の一括チェック
pnpm scan:secrets   # シークレット検出
pnpm build          # tsc で dist/ に出力（start で実行）
```

## テンプレート導入手順

1. `package.json` の `name` をプロジェクト名に変更
2. `LICENSE` のプレースホルダ（`[yyyy]` / `[name of copyright owner]`）を記入、またはライセンスごと差し替え
3. `.github/CODEOWNERS` の `@REPLACE-ME` を実在のユーザー / チームに置換
4. `docs/knowledge/` のサンプルを実プロジェクトの知識で差し替え（運用ルールは [docs/knowledge/index.md](docs/knowledge/index.md)）
5. `corepack enable && pnpm install && pnpm release-check` で健全性を確認

## ドキュメント

- [AGENTS.md](AGENTS.md) — ディレクトリ構成・開発規約（AI エージェント向けガイドライン）
- [docs/knowledge/](docs/knowledge/) — 意思決定・背景・運用手順の知識バンドル
  - [Dev Container 運用](docs/knowledge/runbooks/devcontainer.md) — エージェント環境のセットアップ・認証・シークレット
  - [sbx 運用](docs/knowledge/runbooks/agent-sandbox-sbx.md) — microVM 隔離でのエージェント実行

## リリース

`pnpm release-check` → `CHANGELOG.md` 更新 → バージョンタグ作成。

## ライセンス

[MIT](LICENSE)。`LICENSE` 内の `[yyyy] [name of copyright owner]` は派生先で置換すること。
