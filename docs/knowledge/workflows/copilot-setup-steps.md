---
type: GitHub Actions Workflow
title: Copilot Setup Steps
description: GitHub Copilot 用環境セットアップ手順の妥当性確認。install / lint / typecheck / test が緑であることを保証する。
resource: ../../../.github/workflows/copilot-setup-steps.yml
tags: [ci, copilot, smoke-test]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `workflow_dispatch`
- `push` / `pull_request` で `.github/workflows/copilot-setup-steps.yml` 自身が変わったとき
- 同一 ref で `cancel-in-progress`

# パーミッション

- `contents: read`

# 主な処理

1. pnpm + Node.js セットアップ
2. `pnpm install --frozen-lockfile`
3. `pnpm release-check` (フォーマット + リント + 型チェック + テストを一括)

# 関連

- [biome](../tools/biome.md) / [typescript](../tools/typescript.md) / [vitest](../tools/vitest.md) — `release-check` が呼び出すツール群。
