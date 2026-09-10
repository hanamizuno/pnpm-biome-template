---
type: ADR
title: pnpm 12 へ更新し、設定を pnpm-workspace.yaml へ集約する
description: pnpm 12（Rust 実装）へのピン更新と、pnpm が読まなくなっていた .npmrc 設定の移設・corepack 用 integrity ハッシュの撤去
tags: [toolchain, pnpm, accepted]
timestamp: 2026-09-10T00:00:00Z
---

# ADR-0003: pnpm 12 へ更新し、設定を pnpm-workspace.yaml へ集約する

## Status

Accepted — 2026-09-10

## Context

[ADR-0002](0002-pnpm-without-corepack.md) で corepack を外した際、pnpm 本体の更新は別判断として切り離していた。その更新を行うにあたり、単なるバージョン文字列の差し替えでは済まない点が 3 つ見つかった。いずれもコンテナ上での実測で確認したもの。

**1. `.npmrc` の pnpm 設定は既に読まれていなかった。** 公式ドキュメントは「`.npmrc` からは auth と registry の設定だけを読む。それ以外（`hoistPattern`、`nodeLinker` 等）は `pnpm-workspace.yaml` かグローバル設定に書くこと」と述べている。実際に `pnpm config get` で確認したところ、`.npmrc` に置いていた `auto-install-peers` / `engine-strict` / `strict-peer-dependencies` は **pnpm 11.9.0 でも 12.3.4 でも `undefined`** だった。つまりこの 3 つは以前から効いておらず、ファイルが残っていることで「設定してあるつもり」の状態が続いていた。pnpm 12 が持ち込んだ退行ではなく、既存の穴である。

**2. corepack 用の `+sha512.…` は誰も検証しない。** `packageManager` に付けていた integrity ハッシュは corepack がダウンロードしたパッケージマネージャの tarball を検証するためのもの（値は npm レジストリの tarball の sha512 を hex 化したもので、実際に一致することを確認した）。pnpm 自身はこれを見ておらず、意図的に壊したハッシュを置いてもダウンロード経路を含めて素通りした。corepack を外した以上、手で同期し続ける必要があるだけの飾りになる。

**3. pnpm 12 は `packageManager` のピンをロックファイルに記録する。** ロックファイルに `packageManagerDependencies` と 8 つの `@pnpm/exe.*`（プラットフォーム別ネイティブバイナリ）が integrity 付きで書かれる。そのため **ピンを変えたらロックファイルの再生成が必須** で、放置すると `pnpm install --frozen-lockfile` が `ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE` で落ちる（CI が使う経路）。

## Decision

pnpm を **12.3.4** にピンし、設定を `pnpm-workspace.yaml` に集約する。

* `packageManager` は `pnpm@12.3.4` — **`+sha512.…` は付けない**。pnpm 12 の `pnpm init` が書く形式と同じで、integrity はロックファイルの `@pnpm/exe.*` エントリが担う。手で同期する対象が 1 つ減り、検証されるものだけが残る。
* `.npmrc` は**削除**し、3 つの設定を `pnpm-workspace.yaml` に `autoInstallPeers` / `engineStrict` / `strictPeerDependencies` として移す。これで実際に効くようになる（`pnpm config get` で確認済み）。`Dockerfile` の `COPY .npmrc ./`、`.github/labeler.yml` の項目、`AGENTS.md` のディレクトリ一覧も追随。
* ロックファイルは pnpm 12.3.4 で再生成してコミットする。

棄却した代替案:

* **`.npmrc` をそのまま残す** — 効かない設定を「設定済み」に見せ続けることになる。テンプレートとしては特に有害で、利用者が同じ勘違いを引き継ぐ。
* **12.3.0 / 12.2.1 を選ぶ** — 後述の `minimumReleaseAge` との衝突を避けられるが、衝突は公開から 7 日で自然に解消する一過性のもの。恒久的に古いバージョンを選ぶ理由にはならない。
* **`packageManager` に integrity ハッシュを残す** — 検証されない値を手で維持することになる。

## Consequences

* `pnpm install --frozen-lockfile` / `release-check` / `pnpm audit` と、Dockerfile の base / dev / prod ステージのビルドが pnpm 12.3.4 で通ることを実測で確認済み。
* **公開から 7 日未満のピンは、手元の pnpm がピンと違う人の環境で解決に失敗する。** リポジトリの `minimumReleaseAge`（7 日）は pnpm 自身のダウンロードにも適用され、12.3.4（公開 2026-09-04）を 12.3.0 の環境から実行すると `ERR_PNPM_NO_MATURE_MATCHING_VERSION` になる。**2026-09-11 に自然解消する。** イメージ（Dockerfile / sbx kit）と CI（`pnpm/action-setup`）はピンと同じ版を直接入れるため影響を受けない。今後 pnpm を上げるときは、公開から 7 日待ってからピンするのが安全。
* ロックファイルに `@pnpm/exe.*` が 8 件増える。SBOM・Trivy・`pnpm audit` の対象にも現れる。
* `engineStrict` が実際に有効になった。pnpm 12 では、`optionalDependencies` のサブツリー内でも通常の `dependencies` 辺で到達するパッケージが `engines` 不一致なら install が失敗する（pnpm 11 は警告のみ）。現状の依存では問題ないことを確認済みだが、今後 install が engines で落ちうる点は認識しておくこと。
* pnpm のバージョン文字列のピン箇所は [ADR-0002](0002-pnpm-without-corepack.md) の記載どおり 4 箇所（`package.json`・`Dockerfile` ×2・`.sandbox/kit/spec.yaml`）。加えて **ロックファイルの再生成**が必要になった。
