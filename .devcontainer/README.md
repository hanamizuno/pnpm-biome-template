# .devcontainer

AI エージェント（Claude Code / Codex 等）も動かせる Dev Container の定義。

## 使い方

```bash
# 起動（VS Code なら「Reopen in Container」）
devcontainer up --workspace-folder .

# エージェントを起動（初回はインラインでログインフローが出る）
devcontainer exec --workspace-folder . claude --permission-mode auto
devcontainer exec --workspace-folder . codex

# GitHub CLI の認証
devcontainer exec --workspace-folder . gh auth login --hostname github.com --git-protocol https --web

# 設定変更の反映（VS Code なら「Rebuild Container」）
devcontainer up --workspace-folder . --remove-existing-container
```

認証は named volume に永続化されるため、rebuild 後も再ログインは不要。

詳細（同梱ツール・ホスト設定の継承・PAT / シークレット運用）: [docs/knowledge/runbooks/devcontainer.md](../docs/knowledge/runbooks/devcontainer.md)
