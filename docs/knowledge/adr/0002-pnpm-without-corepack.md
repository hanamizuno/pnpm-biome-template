---
type: ADR
title: pnpm の導入を corepack から npm 直接インストールへ移す
description: Node 25+ が corepack を同梱しなくなり、pnpm 自身が packageManager を解決するようになったため、corepack への依存をやめる
tags: [toolchain, pnpm, docker, accepted]
timestamp: 2026-09-10T00:00:00Z
---

# ADR-0002: pnpm の導入を corepack から npm 直接インストールへ移す

## Status

Accepted — 2026-09-10

## Context

このテンプレートは当初、pnpm を corepack 経由で用意していた（`corepack enable && corepack prepare pnpm@<version> --activate`）。`package.json` の `packageManager` フィールドから版が解決され、Node に同梱されているので追加のインストーラが要らない、という点で当時は合理的な選択だった。

その前提が上流の 2 つの動きで崩れた。

**1. Node.js が corepack を同梱しなくなった。** Node.js TSC は 2025-03-19 の投票で、以降のリリースライン（25+）の公式ディストリビューションに corepack を含めない方針を決め、実装済み。Node 24 以前では experimental のまま残る（[nodejs/node#61207](https://github.com/nodejs/node/pull/61207)、[解説](https://socket.dev/blog/node-js-tsc-votes-to-stop-distributing-corepack)）。corepack 自体が廃止されたわけではない（「非推奨」ではなく「非同梱」）が、Node に入っている前提は置けなくなった。このリポジトリは `.nvmrc` が 24、CI のテストマトリクスが Node 24 / 25 なので、`.nvmrc` を 25 に上げた時点で Dockerfile と sbx kit の `corepack enable` が壊れる。

**2. pnpm 側が corepack を推さなくなった。** 公式インストールページから Corepack の節が消え（[pnpm.io/installation](https://pnpm.io/installation)）、CI ドキュメントには「以前は Corepack を使っていたが、Corepack は pnpm の代わりに JavaScript の shim を置くので `pnpm` 呼び出しのたびに Node.js が起動する。CI は呼び出し回数が多いのでそのコストを毎回払う」旨の注記が入った。`pnpm doctor` は corepack 経由で動いている場合に警告を出す（`pnpm self-update` が使えなくなるため）。

さらに、corepack がやっていた仕事は pnpm 本体に取り込まれている。pnpm 11 の [`pmOnFail`](https://pnpm.io/settings/cli#pmonfail) は既定が `download` で、実行中の pnpm が `packageManager` の宣言と食い違えば pnpm 自身が宣言された版を取得して実行し直す（pnpm 10 系の `managePackageManagerVersions: true` 相当）。つまり corepack を外してもバージョン固定の効果は失われない。

## Decision

pnpm は **npm でシステム全体にインストールする**（`npm install -g pnpm@<version>`）。corepack は使わない。

* 対象は corepack を呼んでいた 3 箇所 — `Dockerfile` の base ステージと devcontainer ステージ、`.sandbox/kit/spec.yaml`。
* `COREPACK_HOME` と、root ビルド／非 root 実行のためのキャッシュ権限調整（`chmod -R a+rX /opt/corepack`）は不要になり削除する。`npm install -g` の出力先はもともと全ユーザーから読める。`.devcontainer/compose.yaml` の `COREPACK_ENABLE_DOWNLOAD_PROMPT` も削除。
* CI は変更しない。もともと corepack ではなく `pnpm/action-setup` を使っている。
* イメージに焼くバージョンは `package.json` の `packageManager` と同じ値を明示的にピンする。

棄却した代替案:

* **スタンドアロンスクリプト（`get.pnpm.io/install.sh`）** — pnpm 公式の推奨だが、インストール先が `$PNPM_HOME` 配下のユーザースコープで PATH 設定も要る。root でビルドして非 root で実行するコンテナとは相性が悪く、corepack の権限問題を別の形で持ち込むだけになる。
* **corepack を npm から入れて使い続ける** — Node 非同梱の問題は解けるが、shim 一段分の起動コストと、pnpm 側が corepack から離れていく方向は残る。依存を 1 つ増やして何も得られない。
* **mise / asdf などのバージョンマネージャに寄せる** — このテンプレートの範囲に対してツールが 1 つ増えすぎる。`pmOnFail: ignore` にして外部ツールへ委譲する道は残っている。

pnpm 12 への更新は別の判断として切り離す。本 ADR の範囲は 11.9.0 のまま導入経路だけを差し替えること（更新自体は直後に [ADR-0003](0003-pnpm-12-and-workspace-settings.md) で行った）。

## Consequences

* `.nvmrc` と Docker ベースイメージを Node 25 以降へ上げる道が開いた。これが本変更の主目的。
* `pnpm self-update` と `pnpm doctor` が正常に使えるようになる。
* pnpm のバージョン文字列が 4 箇所（`package.json` の `packageManager`、`Dockerfile` ×2、`.sandbox/kit/spec.yaml`）に散る点は corepack 時代から変わらない。**バージョンを上げるときは 4 箇所すべてを揃えること。** 揃え忘れてもインストールは失敗せず、`pmOnFail: download` の既定により pnpm が宣言された版を実行時にダウンロードして動く — 壊れないが、イメージに焼いた版が使われず起動が遅くなる形で表面化する。
* イメージビルド時に npm レジストリへの到達性が要る。corepack も同じくダウンロードが必要だったので、ネットワーク要件としては同等。
* 既存のコンテナ／サンドボックスには自動では反映されない。Dev Container は rebuild、sbx は `sbx rm` → `sbx run` で作り直す（[runbooks/devcontainer.md](/docs/knowledge/runbooks/devcontainer.md)、[runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md)）。
