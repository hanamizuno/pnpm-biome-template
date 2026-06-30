---
type: Index
title: Architecture Decision Records
description: ほぼ不可逆な設計判断とその理由のログ
tags: [adr]
timestamp: 2026-06-30T00:00:00Z
---

# Architecture Decision Records

ほぼ不可逆な設計判断と **その理由** を時系列で記録する。フォーマットは軽量な [MADR](https://adr.github.io/madr/) スタイル。

## 命名規則

`NNNN-kebab-case-title.md` (4 桁ゼロ埋めの連番)。

## ステータス語彙

* **Proposed** — 議論中。まだ実装されていない可能性がある。
* **Accepted** — 採用済み。現在のコードと一致しているはず。
* **Superseded** — 新しい ADR に置き換えられた。フロントマターの `tags` と本文 `# Status` の両方に `Superseded by ADR-XXXX` と明記する。
* **Deprecated** — 後継なしで廃止。

ADR のステータスが変わったら、フロントマターの `tags:` と本文の `# Status` の両方を更新し、[/docs/knowledge/log.md](/docs/knowledge/log.md) にもエントリを追記すること。

## Index

* [0001-sample-decision.md](0001-sample-decision.md) — サンプル。実際の ADR が書けたら置き換える (もしくは削除する)。
