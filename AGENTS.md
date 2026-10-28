# AGENTS.md

AI コーディングエージェント向けのガイドライン。ユーザーとの会話、ドキュメント・コメント・コミットメッセージ・プルリクエストは日本語で書くこと。

## プロジェクト概要

Node.js + pnpm + Biome の TypeScript テンプレート。フォーマット・リントは Biome、テストは vitest。

コンテナ構成は `Dockerfile`（`dev` / `prod` のマルチステージ）と `compose.dev.yml` / `compose.yml`。AI エージェントは Docker Sandboxes（`sbx`）用 kit（`.sandbox/`、ホスト側で実行）で microVM 内に隔離して実行する。詳細は [sbx 運用](docs/knowledge/runbooks/agent-sandbox-sbx.md)。

## 開発コマンド

```bash
pnpm dev            # tsx --watch で開発実行
pnpm test           # テスト（test:cov でカバレッジ、bench でベンチマーク）
pnpm fmt            # フォーマット適用（fmt:check はチェックのみ）
pnpm lint           # リント（biome check . でフォーマット + リント）
pnpm check          # 型チェック + フォーマット + リント
pnpm release-check  # CI 相当の一括チェック（biome ci + typecheck + test）
pnpm scan:secrets   # シークレット検出
pnpm build          # tsc で dist/ に出力（start で実行）
pnpm tsx src/main.ts

pnpm install --frozen-lockfile   # 依存インストール
pnpm add [-D] <package>          # 依存追加
```

## ディレクトリ構造

```
src/                    # main.ts / main.test.ts / main.bench.ts
docs/knowledge/         # OKF v0.1 知識バンドル（architecture / adr / conventions / runbooks / research）
.sandbox/               # Docker Sandboxes（sbx）用 kit
.github/                # workflows / dependabot / labels / Issue・PR テンプレート
.vscode/                # biome を既定フォーマッタに、保存時 fixAll
.claude/settings.json   # Claude Code の既定権限モード（auto）
tsconfig.json           # 型チェック用（build 用は tsconfig.build.json がテスト/ベンチを除外）
biome.json / vitest.config.ts / pnpm-workspace.yaml / .nvmrc
.pre-commit-config.yaml # biome-check / typecheck / secretlint（prek install で有効化）
```

設定値の詳細は各設定ファイルを直接読むこと（ここでは重複させない）。

## CI

`lint`（biome ci + tsc + secretlint）/ `test`（カバレッジを PR にコメント）/ `lint_gha`（actionlint + zizmor）/ `lint_docker`（hadolint）/ `security`（pnpm audit + Trivy、日次）/ `sbom` / `deps-update`（週次）/ `label_pr` / `labels`。

共通規約: top-level `permissions: {}` + job 単位の最小権限、`concurrency`、`timeout-minutes`、アクションの commit SHA 固定（`.zizmor.yml` の `hash-pin` で強制）。

## 開発のベストプラクティス

- 型安全性を優先し、`any` を避ける
- 機能追加前にテストを書く
- 論理的な単位で小さくコミットする
- コードから読み取れない意思決定・背景・運用知見は `docs/knowledge/` に記録する（運用ルールは [docs/knowledge/index.md](docs/knowledge/index.md)）

## シークレットの扱い

- シークレットをコミットしないこと。
- GitHub 認証やタスク用シークレットは sbx のホスト側プロキシが HTTP ヘッダに自動注入する。環境変数（`GH_TOKEN` 等）の中身は sentinel で実値ではないため、トークン値の取得・表示を試みないこと。新しいシークレットが要る場合は `.sandbox/kit/spec.yaml` の `credentials` に追加し、ホストで `sbx secret set` する（[sbx 運用](docs/knowledge/runbooks/agent-sandbox-sbx.md)「タスク用シークレット」）。
