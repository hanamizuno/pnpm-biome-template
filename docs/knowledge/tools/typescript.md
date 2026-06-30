---
type: Tool
title: TypeScript
description: strict + nodenext + ES2025 を前提とする型システム設定。型チェック用とビルド用で tsconfig を分離。
resource: https://www.typescriptlang.org/
tags: [typescript, typecheck, build]
timestamp: 2026-06-30T00:00:00Z
---

# 概要

`tsc` は型チェックとビルドの 2 用途で利用する。テスト/ベンチを含む型チェック用と、`src` のみをビルド対象とする本番用を分けている。

# 設定の要点

- 型チェック用: [`tsconfig.json`](../../../tsconfig.json)
  - `target` / `lib`: ES2025
  - `module` / `moduleResolution`: nodenext
  - `strict` に加えて `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `isolatedModules`, `verbatimModuleSyntax` を有効化
  - `rootDir`: `./src` / `outDir`: `./dist`
- ビルド用: [`tsconfig.build.json`](../../../tsconfig.build.json) — テスト/ベンチを `exclude` で除外

# 主なコマンド

| コマンド | 用途 |
|---|---|
| `pnpm typecheck` | 型チェック (`tsc --noEmit`) |
| `pnpm build` | `tsconfig.build.json` でビルド |
| `pnpm start` | ビルド成果物を実行 |
| `pnpm tsx src/main.ts` | tsx で TS を直接実行 |

# 関連

- [vitest](vitest.md) — `.test.ts` / `.bench.ts` は型チェック対象、ビルドからは除外。
- [lint workflow](../workflows/lint.md) で `pnpm typecheck` を実行する。
