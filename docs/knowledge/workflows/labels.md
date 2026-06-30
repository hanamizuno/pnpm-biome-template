---
type: GitHub Actions Workflow
title: Sync Labels
description: .github/labels.yml を Single Source of Truth として、リポジトリのラベルを作成・更新する。
resource: ../../../.github/workflows/labels.yml
tags: [ci, labels, automation]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `push` / `pull_request` (main) で以下のいずれかが変わったとき:
  - `.github/labels.yml`
  - `.github/scripts/sync-labels.sh`
  - `.github/workflows/labels.yml`
- `workflow_dispatch`

# パーミッション

- `contents: read`
- `issues: write` (ラベル CRUD のため)

# 主な処理

1. `actions/checkout` (`persist-credentials: false`)
2. `bash .github/scripts/sync-labels.sh .github/labels.yml`
   - PR では `DRY_RUN=1` を渡して差分のみ表示
   - push (main) では実反映

# Source of Truth

- [`.github/labels.yml`](../../../.github/labels.yml) — ラベル一覧 (name / color / description)
- [`.github/scripts/sync-labels.sh`](../../../.github/scripts/sync-labels.sh) — 同期スクリプト
  - 未登録ラベルは `gh label create` で追加
  - 色・説明にドリフトがあれば `gh label edit` で更新
  - デフォルトでは削除しない。ローカルで `PRUNE=1` を付けたときのみ削除

# 関連

- [deps-update](deps-update.md) — `dependencies` ラベルを利用するため、当ワークフローで先にラベルを揃える。
