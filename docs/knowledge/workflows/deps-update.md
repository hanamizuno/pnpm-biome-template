---
type: GitHub Actions Workflow
title: Update Dependencies
description: 毎週月曜に pnpm update を回し、audit とテストが通れば PR を自動作成する。
resource: ../../../.github/workflows/deps-update.yml
tags: [ci, dependencies, automation]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `schedule`: 毎週月曜 09:00 UTC (JST 18:00)
- `workflow_dispatch` (`update_mode`: `compatible` / `latest` を選択可)

# パーミッション

- `contents: write`
- `pull-requests: write`

# 主な処理

1. `pnpm outdated` でアップデート候補の有無を判定
2. `compatible` (デフォルト) は `pnpm update`、`latest` は `pnpm update --latest`
3. `pnpm audit --audit-level=high` (high/critical があれば中断)
4. `pnpm test` (失敗時は PR を作らない)
5. ブランチ `deps/update-dependencies` に `--force-with-lease` で push
6. 既存の同名 PR が無ければ `dependencies` ラベル付きで作成

# 関連

- [security](security.md) — 同じ audit ルールが日次でも走る。
- [labels](labels.md) — `dependencies` ラベルは `.github/labels.yml` で定義しておく必要がある。
