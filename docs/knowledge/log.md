# Knowledge Bundle Update Log

## 2026-09-05

* **Move**: `.devcontainer/README.md` / `.sandbox/README.md` の詳細を [runbooks/devcontainer.md](/docs/knowledge/runbooks/devcontainer.md) と [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) へ移動し、sbx の実機検証ログを [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) へ切り出し。元の README はポインタのみに縮小。
* **Trim**: `README.md` / `AGENTS.md` / バンドルの `index.md` を圧縮し、不要な表を箇条書きへ。

## 2026-07-02

* **Add**: [research/](/docs/knowledge/research/index.md) 区画を追加（調査・比較検討のスナップショット置き場）。サンプルとして [research/sample-research.md](/docs/knowledge/research/sample-research.md) を配置。

## 2026-06-30

* **Bootstrap**: `docs/knowledge/` を OKF v0.1 バンドルのスケルトンとして初期化。
* **Sample**: 各サブディレクトリにサンプルドキュメントを 1 つずつ配置。実知識を蓄積する際に置き換える前提。
  * [architecture/sample-service-overview.md](/docs/knowledge/architecture/sample-service-overview.md)
  * [adr/0001-sample-decision.md](/docs/knowledge/adr/0001-sample-decision.md)
  * [conventions/sample-convention.md](/docs/knowledge/conventions/sample-convention.md)
  * [runbooks/sample-runbook.md](/docs/knowledge/runbooks/sample-runbook.md)

<!--
今後は、ドキュメントの追加・移動・廃止、またはこのバンドル内の決定のステータス変更があったときに
ここへ追記してください。エントリは ISO 形式の日付見出し (`## YYYY-MM-DD`) でグループ化し、
各箇条書きは簡潔に保ち、対象ファイルへリンクしてください。
-->
