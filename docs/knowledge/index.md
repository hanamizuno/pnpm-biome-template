---
okf_version: "0.1"
---

# Knowledge Bundle

このディレクトリは [Open Knowledge Format (OKF) v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) に準拠した知識バンドルです。AI エージェントと人間の双方が、プレーンな Markdown として読み書きできる共有メモリとして運用します。

このテンプレートでは **スケルトンのみ** を同梱します。ディレクトリ構成と予約ファイル (`index.md` / `log.md`)、そして「サブディレクトリごとに 1 つだけ」の見本ドキュメントを置いてあります。プロジェクトが育つにつれて、サンプルは実コンテンツで上書きしてください。プレースホルダを溜め込まないようにしましょう。

ユーザー向けのドキュメント (`README.md`) や AI エージェント向けのガイドライン (`AGENTS.md`) とは異なり、このバンドルは **コードや git 履歴からは読み取りにくい意思決定・背景・運用知見** を蓄積するための場所です。コードベースや `git log` から復元できる情報は書かないでください。

## レイアウト

* [architecture/](architecture/) — システム構造・データフロー・段階的なビルド計画
* [adr/](adr/) — Architecture Decision Records (決定とその理由)
* [conventions/](conventions/) — テスト・エラーハンドリング等のリポジトリ横断の取り決め
* [runbooks/](runbooks/) — 障害対応や定型運用の手順
* [log.md](log.md) — バンドル全体の更新ログ

## OKF 運用ルール

* `index.md` と `log.md` は予約ファイル名です。概念ドキュメントとして使ってはいけません。
* バンドルルートの `index.md` のみ `okf_version` フロントマターを持てます。
* それ以外の `.md` ファイルは **必ずフロントマターを持ち**、最低でも `type` を含めること。
* リンクは **バンドルルート相対** (リポジトリ上は `/docs/knowledge/...` で始まる絶対パス) を優先。ファイル移動に強いです。
* 1 ファイル = 1 概念。階層は親子関係を表現します。
* 推奨フィールド: `type` (必須)、`title`、`description`、`tags`、`timestamp`。リソースを指し示すなら `resource`。
* `timestamp` は ISO 8601 (例: `2026-06-30T00:00:00Z`)。
* ドキュメントを追加・更新したら、該当サブディレクトリの `index.md` を直し、バンドル全体に影響する変更なら [log.md](log.md) にも追記してください。

## 新規概念ドキュメントのテンプレート

```markdown
---
type: ADR  # もしくは Architecture Note / Convention / Runbook / Reference 等
title: 短く分かりやすいタイトル
description: 一行サマリ (プレビュー・検索で使う)
tags: [領域タグ, ステータスタグ]
timestamp: 2026-06-30T00:00:00Z
---

# 本文
```

`type` の語彙は意図的に中央集権化されていません。ドメインに合うものを選んでください。読者 (人間とエージェント) は未知の `type` 値を許容することが期待されています。このテンプレートのサンプルでは `Architecture Note` / `ADR` / `Convention` / `Runbook` / `Index` を使っています。
