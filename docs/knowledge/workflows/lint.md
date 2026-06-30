---
type: GitHub Actions Workflow
title: Lint
description: Biome のフォーマット/リント・TypeScript 型チェック・secretlint をまとめて検証する。
resource: ../../../.github/workflows/lint.yml
tags: [ci, lint, typecheck, secrets]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `push` / `pull_request` (main)
- 同一 ref で `cancel-in-progress`

# パーミッション

- `contents: read`

# ステップ

1. `actions/checkout` (`persist-credentials: false`)
2. `pnpm/action-setup`
3. `actions/setup-node` (`node-version-file: .nvmrc`, `cache: pnpm`)
4. `pnpm install --frozen-lockfile`
5. `pnpm biome ci .`
6. `pnpm typecheck`
7. `pnpm scan:secrets`

# 関連

- [biome](../tools/biome.md) — `biome ci` を実行する。
- [typescript](../tools/typescript.md) — `pnpm typecheck` (`tsc --noEmit`)。
- [lint-gha](lint-gha.md) — Actions 自体のリント。
