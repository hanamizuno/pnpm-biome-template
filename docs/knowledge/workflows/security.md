---
type: GitHub Actions Workflow
title: Security Audit
description: pnpm audit による依存関係の脆弱性監査。high 以上が出れば失敗する。
resource: ../../../.github/workflows/security.yml
tags: [ci, security, dependencies]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `push` / `pull_request` (main) で `package.json` / `pnpm-lock.yaml` が変わったとき
- `schedule`: 毎日 09:00 UTC (JST 18:00)
- `workflow_dispatch`

# パーミッション

- `contents: read`

# 主な処理

1. `pnpm install --frozen-lockfile`
2. `pnpm audit` の結果を `GITHUB_STEP_SUMMARY` に書き出し
3. `pnpm audit --audit-level=high` で high / critical があれば失敗

# 関連

- [deps-update](deps-update.md) — 更新 PR でも同等の audit が走る。
- [pnpm](../tools/pnpm.md) — audit の実行主体。
