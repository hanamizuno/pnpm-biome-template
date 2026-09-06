---
okf_version: "0.1"
---

# Knowledge Bundle

[Open Knowledge Format (OKF) v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) 準拠の知識バンドル。AI エージェントと人間が共有メモリとして読み書きする。

`README.md`（ユーザー向け）や `AGENTS.md`（エージェント向けガイドライン）とは異なり、ここには **コードや git 履歴から復元できない意思決定・背景・運用知見** を置く。コードベースや `git log` から読み取れる情報は書かない。

テンプレートにはスケルトンとサンプルのみ同梱しているので、プロジェクトが育ったら実コンテンツで置き換える。

## レイアウト

* [architecture/](architecture/) — システム構造・データフロー・ビルド計画
* [adr/](adr/) — Architecture Decision Records（決定とその理由）
* [conventions/](conventions/) — リポジトリ横断の取り決め
* [runbooks/](runbooks/) — 障害対応・定型運用の手順
* [research/](research/) — 調査・比較検討のスナップショット
* [log.md](log.md) — バンドル全体の更新ログ

## 運用ルール

* `index.md` / `log.md` は予約ファイル名。概念ドキュメントには使わない
* `okf_version` フロントマターを持てるのはバンドルルートの `index.md` のみ
* 他の `.md` は必ずフロントマターを持ち、最低でも `type` を含める。推奨は `type`（必須）・`title`・`description`・`tags`・`timestamp`（ISO 8601）。リソースを指すなら `resource`
* 1 ファイル = 1 概念。階層で親子関係を表す
* リンクはバンドルルート相対（リポジトリ上は `/docs/knowledge/...`）を優先する
* ドキュメントを追加・更新したら該当サブディレクトリの `index.md` を直し、バンドル全体に影響するなら [log.md](log.md) にも追記する

## 新規ドキュメントのテンプレート

```markdown
---
type: ADR  # Architecture Note / Convention / Runbook / Research / Reference 等
title: 短いタイトル
description: 一行サマリ
tags: [領域タグ, ステータスタグ]
timestamp: 2026-06-30T00:00:00Z
---

# 本文
```

`type` の語彙は中央集権化されていない。ドメインに合うものを選び、読者は未知の値を許容する。
