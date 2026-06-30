---
type: Tool
title: vitest
description: TypeScript ネイティブで動作するテスト/ベンチランナー。v8 カバレッジ計測込み。
resource: https://vitest.dev/
tags: [test, bench, coverage]
timestamp: 2026-06-30T00:00:00Z
---

# 概要

`vitest` をテスト/ベンチ両用ランナーとして採用。トランスパイル不要で `.ts` をそのまま実行できる。

# 設定の要点

設定ファイル: [`vitest.config.ts`](../../../vitest.config.ts)

- `include`: `src/**/*.test.ts`
- `benchmark.include`: `src/**/*.bench.ts`
- `clearMocks` / `restoreMocks`: 有効
- `coverage.provider`: `v8`
- `coverage.reporter`: `text`, `html`
- カバレッジしきい値: 80%

# 主なコマンド

| コマンド | 用途 |
|---|---|
| `pnpm test` | テスト実行 |
| `pnpm test:cov` | カバレッジレポート付きでテスト |
| `pnpm bench` | ベンチマーク実行 |

# 関連

- [test workflow](../workflows/test.md) — PR にカバレッジコメントを投稿する。
- [typescript](typescript.md) — テストファイルは `tsconfig.json` に含み、ビルド時は `tsconfig.build.json` で除外する。
