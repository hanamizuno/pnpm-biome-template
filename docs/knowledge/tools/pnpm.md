---
type: Tool
title: pnpm
description: 高速・省ディスクなパッケージマネージャー。本テンプレートの標準。
resource: https://pnpm.io/
tags: [package-manager, workspace]
timestamp: 2026-06-30T00:00:00Z
---

# 概要

依存解決と `node_modules` 配置に content-addressable store を使う pnpm を採用。同一バージョンの依存はマシン上で 1 度だけ保存され、各プロジェクトにはハードリンクで配備される。

# 設定の要点

- バージョン固定: [`.nvmrc`](../../../.nvmrc) (Node.js v24) と [`package.json` の `packageManager`](../../../package.json)
- ワークスペース設定: [`pnpm-workspace.yaml`](../../../pnpm-workspace.yaml) — `allowBuilds` 等
- 挙動: [`.npmrc`](../../../.npmrc) — `engine-strict=true` で Node バージョン強制

# 主なコマンド

| コマンド | 用途 |
|---|---|
| `pnpm install --frozen-lockfile` | CI などでロックファイルを尊重したインストール |
| `pnpm add <pkg>` | 依存追加 |
| `pnpm add -D <pkg>` | 開発依存追加 |
| `pnpm update` | 依存更新 |
| `pnpm tsx src/main.ts` | tsx 経由で TS を直接実行 |

# 関連

- [biome](biome.md) / [vitest](vitest.md) / [typescript](typescript.md) は pnpm スクリプト経由で呼び出される。
- 自動更新は [deps-update workflow](../workflows/deps-update.md) が毎週月曜に PR を出す。
