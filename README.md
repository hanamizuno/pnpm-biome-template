# pnpm + Biome Template

シンプルな Node.js + pnpm + Biome プロジェクトのテンプレートです。

## 機能一覧

- TypeScript による型安全な開発環境
- Biome による高速なフォーマット・リント
- テスト・ベンチマーク・カバレッジ計測（vitest, しきい値 80%）
- pre-commit hooks による品質保証（biome / typecheck / secretlint）
- GitHub Actions による CI（Node 24/25 マトリクス、Actions は commit SHA・Dev Container Features と Docker ベースイメージは sha256 digest で固定、依存自動更新）
- PR 自動ラベリング（actions/labeler — ハーネス変更 PR に `meta` ラベル）とラベル定義の同期（`.github/labels.yml`）
- セキュリティスキャン（secretlint / pnpm audit / Trivy — push・cron 時は SARIF を Security タブへ集約）
- SBOM 生成（CycloneDX、cdxgen）
- Dockerfile / GitHub Actions 自体のリント（hadolint / actionlint / zizmor）
- VS Code Dev Containers: AI エージェントツールチェーン（Claude Code CLI、Codex CLI、GitHub CLI、共通ユーティリティ）を [Dev Container Features](https://containers.dev/implementors/features/) と post-create セットアップで重ねて注入
- Chrome DevTools MCP + headless Chromium: エージェントがコンテナ内で画面の見た目をデバッグ（スクリーンショット・コンソール・ネットワーク確認）
- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（sbx）用 kit: microVM + deny-by-default ネットワーク + credential 非搬入の、より強い隔離でエージェントを実行（`.sandbox/`）

## このテンプレートの導入手順

テンプレートからリポジトリを作成したら:

1. `package.json` の `name` をプロジェクト名に変更する（必要なら `description` 等のメタデータも追加）。
2. `LICENSE` のプレースホルダ（`[yyyy]`、`[name of copyright owner]`）を記入する — もしくはライセンスごと差し替える。
3. `.github/CODEOWNERS` の `@REPLACE-ME` を実在の GitHub ユーザー / チームに置き換える。
4. `docs/knowledge/` のサンプルドキュメントを実プロジェクトの知識で差し替える（運用ルールは `docs/knowledge/index.md` を参照）。
5. `corepack enable && pnpm install && pnpm release-check` を実行し、セットアップ後のプロジェクトが健全なことを確認する。

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

VS Code Dev Container を AI コーディングエージェント（Claude Code / Codex 等）の実行環境としても利用できます。同梱ツール・認証手順・ホスト設定の継承・サンドボックスのモード・PAT 運用などの詳細は [.devcontainer/README.md](.devcontainer/README.md) を参照してください。

## AI Agent Sandbox（Docker Sandboxes）

より強い隔離（microVM・deny-by-default ネットワーク・シークレット非搬入）でエージェントを無人実行するための [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) 用 kit を `.sandbox/` に同梱しています。Dev Container と併存し、ホスト側で `sbx run claude --clone --kit ./.sandbox/kit` のように使います。詳細は [.sandbox/README.md](.sandbox/README.md) を参照してください。

## リリースチェックリスト

1. `pnpm release-check` を実行してすべてのチェックが通ることを確認
2. `CHANGELOG.md` を更新
3. バージョンタグを作成

## ライセンス

[MIT](LICENSE)。`LICENSE` 内の `[yyyy] [name of copyright owner]` は派生先で年と著作権者名に置換してください。
