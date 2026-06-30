---
type: GitHub Actions Workflow
title: Lint GitHub Actions
description: zizmor で .github/workflows 配下のセキュリティ問題 (token-permissions, expression injection 等) を検出する。
resource: ../../../.github/workflows/lint_gha.yml
tags: [ci, security, github-actions]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `push` / `pull_request` で `.github/**` が変わったとき

# パーミッション

- `contents: read`

# 主な処理

1. Python セットアップ
2. `pip install zizmor`
3. `zizmor .github/workflows`

# 関連設定

- [`.zizmor.yml`](../../../.zizmor.yml) — リポジトリレベルの zizmor 設定 (除外ルール等)。

# 関連

- [labels](labels.md) / [test](test.md) / [lint](lint.md) など全ワークフローの安全性チェックを担う。
