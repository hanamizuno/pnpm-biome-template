# .sandbox

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)（`sbx`）でエージェントを microVM 内で動かすための kit。**ホスト側で実行する**（devcontainer の中からは使えない）。

- `kit/` — 共有 mixin（Node + pnpm + Chromium + MCP + ネットワーク / credential ルール）
- `claude-auto/` / `codex-approve/` — 既定の YOLO 起動を差し替える fork kit
- 手順: [docs/knowledge/runbooks/agent-sandbox-sbx.md](../docs/knowledge/runbooks/agent-sandbox-sbx.md) / 検証状況: [docs/knowledge/research/sbx-verification.md](../docs/knowledge/research/sbx-verification.md)
