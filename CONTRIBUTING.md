# コントリビューションガイド

このテンプレートへの貢献を歓迎します。以下の手順に従ってください。

## 開発フロー

1. リポジトリをフォーク
2. ブランチを切る（例: `feat/<topic>`, `fix/<topic>`）
3. `pnpm install` で依存をインストール
4. 変更を実装。コミット前に `pnpm release-check` が通ることを確認
5. プルリクエストを作成（[PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) のチェック項目を埋める）

## 言語

会話・コミットメッセージ・PR 本文・コードコメント・ドキュメントは
**日本語**で書いてください（[AGENTS.md](AGENTS.md) 参照）。

## コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に準拠します。

- `feat:` 新機能
- `fix:` バグ修正
- `refactor:` 内部構造の変更
- `chore:` ビルド・設定・補助ツール
- `docs:` ドキュメントのみ
- `test:` テストの追加・修正
- `ci:` CI 設定の変更

## 必須チェック

PR 作成前にローカルで以下を実行し、すべてグリーンであることを確認してください。

```bash
pnpm release-check   # フォーマット + lint + typecheck + test
pnpm scan:secrets    # シークレット検出
```

`prek install` を済ませていれば pre-commit hook で自動実行されます。

## レビューの観点

- [ ] テストがあるか（バグ修正はリグレッションテストが望ましい）
- [ ] 型エラーがない（`pnpm typecheck`）
- [ ] フォーマット・lint をパスする（`pnpm biome ci .`）
- [ ] 破壊的変更がないか、ある場合は CHANGELOG に明記
- [ ] ドキュメントの更新（README / AGENTS.md / CHANGELOG.md）
