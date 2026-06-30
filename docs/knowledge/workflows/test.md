---
type: GitHub Actions Workflow
title: Test and Coverage
description: vitest を Node.js 24 / 25 のマトリクスで実行し、PR にカバレッジレポートをコメントする。
resource: ../../../.github/workflows/test.yml
tags: [ci, test, coverage]
timestamp: 2026-06-30T00:00:00Z
---

# トリガー

- `push` / `pull_request` (main)
- 同一 ref で `cancel-in-progress`

# マトリクス

- Node.js 24 (LTS)
- Node.js 25 (current / odd release)

# パーミッション

- `contents: read`
- `pull-requests: write` (PR コメント投稿のため)

# 主な処理

1. `pnpm install --frozen-lockfile`
2. `pnpm test:cov` (出力を `GITHUB_STEP_SUMMARY` と `GITHUB_OUTPUT` に記録)
3. Node 24 マトリクスのみ:
   - `coverage/` を Artifact としてアップロード
   - PR の場合、既存のカバレッジコメントを更新 / 無ければ新規作成

# 関連

- [vitest](../tools/vitest.md) — カバレッジしきい値 80%、provider は `v8`。
- [lint workflow](lint.md) — 型チェックとリントは別ワークフローで担当。
