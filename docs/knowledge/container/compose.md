---
type: Container Compose
title: Docker Compose
description: 開発用 (compose.dev.yml) と本番用 (compose.yml) の 2 ファイル構成。
resource: ../../../compose.yml
tags: [docker, compose, dev, prod]
timestamp: 2026-06-30T00:00:00Z
---

# ファイル

- 本番: [`compose.yml`](../../../compose.yml)
  - `Dockerfile` の `prod` ターゲットをビルド
  - `restart: unless-stopped`
- 開発: [`compose.dev.yml`](../../../compose.dev.yml)
  - `dev` ターゲットをビルド
  - `.` を `/workspace` に bind mount (cached)
  - `node_modules` だけはホストで上書きしないよう anonymous volume
  - `CHOKIDAR_USEPOLLING=1` — bind mount 越しの変更検知を polling 化

# 起動例

```bash
# 開発
docker compose -f compose.dev.yml up

# 本番
docker compose up -d
```

# 関連

- [dockerfile](dockerfile.md) — 両 compose が参照する Dockerfile。
- [devcontainer](devcontainer.md) — 開発時は Dev Container 経由でも起動可能。
