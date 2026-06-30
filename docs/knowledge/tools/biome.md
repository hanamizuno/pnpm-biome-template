---
type: Tool
title: Biome
description: フォーマッターとリンターを 1 ツールで提供する Rust 製の開発支援ツール。
resource: https://biomejs.dev/
tags: [formatter, linter, javascript, typescript]
timestamp: 2026-06-30T00:00:00Z
---

# 概要

Biome v2 を採用。`prettier` + `eslint` 相当をシングルバイナリでまかない、CI では `pnpm biome ci .` でフォーマット差分とリント違反をまとめて検出する。

# 設定の要点

設定ファイル: [`biome.json`](../../../biome.json)

- `vcs.useIgnoreFile`: `.gitignore` を尊重
- `formatter.lineWidth`: 100
- `formatter.indentStyle`: space (2 spaces)
- `javascript.formatter`: セミコロンあり / ダブルクォート
- `linter`: recommended ルール
- `assist.actions.source.organizeImports`: 有効 (v2 のパス)

# 主なコマンド

| コマンド | 用途 |
|---|---|
| `pnpm fmt` | 書き換えありのフォーマット |
| `pnpm fmt:check` | フォーマット差分のチェックのみ (CI 用) |
| `pnpm lint` | リント実行 |
| `pnpm biome check .` | フォーマット + リント |
| `pnpm check` | Biome に加えて型チェックも実行 |

# 関連

- [lint workflow](../workflows/lint.md) で `biome ci` が走る。
- [pre-commit](https://github.com/j178/prek) からも `biome-format` / `biome-lint` を実行する (`.pre-commit-config.yaml`)。
