## 概要

Docker 開発コンテナ向けの追加ユーティリティインストーラー。公式の [features](https://github.com/uraitakahito/features) と組み合わせ、Claude Code を含む開発環境を構築するための補助パッケージ群を提供します。

## 開発時の動作確認手順

[hello-javascript](https://github.com/uraitakahito/hello-javascript) の開発用
Dockerfile を取得して使います。ランタイムごとに 2 本あるので、使う方を選んでください。

```bash
BASE=https://raw.githubusercontent.com/uraitakahito/hello-javascript/refs/tags/1.5.19

# Docker / OrbStack の場合
curl -L -O "$BASE/Dockerfile.dev.docker"

# Apple container の場合
curl -L -O "$BASE/Dockerfile.dev.container"

curl -L -O "$BASE/docker-entrypoint.sh"
chmod 755 docker-entrypoint.sh
```

続きの手順はDockerfile内のコメントを参照してください。

## cfn-lint

`ADDCFNLINT=true` で [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) を
`/usr/local/bin/cfn-lint` に入れます。**`ADDUV=true` が前提**です。

版は `CFNLINTVERSION`（既定 `1.51.2`）で指定します。

graphify と同じく `uv tool install` を使うので、イメージに `python3` は要りません
（適切な Python が無ければ uv が取得します）。

## graphify

`ADDGRAPHIFY=true` で [graphify](https://github.com/Graphify-Labs/graphify) の CLI を
`/usr/local/bin/graphify` に入れます。**`ADDUV=true` が前提**です（`uv tool install` を使うため。
Python は不要 — uv が専用の CPython を取得します）。

```dockerfile
RUN ADDUV=true ADDGRAPHIFY=true \
      /usr/src/extra-utils/utils/install.sh
```

| 変数 | 既定 | 用途 |
| --- | --- | --- |
| `GRAPHIFYVERSION` | `0.9.28` | 固定する版 |
| `GRAPHIFYEXTRAS` | (空) | extras をカンマ区切りで。`mcp` / `neo4j` / `falkordb` / `pdf` / `watch` / `svg` |

- PyPI 上のパッケージ名は **`graphifyy`**（y が 2 つ)。コマンド名だけが `graphify` です。
  同名の別プロジェクトが PyPI にあるため、この違いは意図的なものです。
- `uvx graphify` は動きません。`uv tool run` は第 1 語をパッケージ名として解決するので、
  一時実行するなら `uvx --from graphifyy graphify ...` と書きます。

### スキル登録（`graphify install`）

CLI を入れただけでは AI アシスタントは graphify を知りません。`graphify install` が
スキル定義と「コードの質問はまずグラフに問い合わせろ」という指示を書き込みます。
ホームやカレントディレクトリを書き換える操作なので**イメージには含めていません**
（ビルド時に root で実行しても利用者には効きません）。コンテナ内で 1 度実行してください。

```sh
# 開発ユーザでコンテナに入り、対象リポジトリのルートで
graphify install            # ユーザプロファイル(~/.claude/)へ。全プロジェクトに効く
graphify install --project  # このリポジトリ(./.claude/)へ。フックが付くのはこちらだけ
```

| スコープ | 生成物 | フック |
| --- | --- | --- |
| 既定 | `~/.claude/CLAUDE.md`, `~/.claude/skills/graphify/` | なし |
| `--project` | `./CLAUDE.md`, `./.claude/`（`CLAUDE.md` / `skills/graphify/` / `settings.json`） | あり |

- 生成物はすべて Markdown と JSON の設定ファイルです。`--project` のときだけ
  `.claude/settings.json` に PreToolUse フックが登録され、`Bash|Grep` と `Read|Glob` の
  直前に graphify が割り込みます。`--strict`（`graphify query` が 1 度通るまで最初の生ファイル
  読みをブロック）は Claude Code の `--project` 専用です。
- `--platform` で Claude Code 以外にも書けます（`codex` / `cursor` / `gemini` など 23 種）。
- **フックには実行時のパスがそのまま焼き込まれます。** このイメージで PATH 経由で叩くと
  `/usr/local/bin/graphify hook-guard ...` が記録されます。コンテナ内では安定しますが、
  ホストには無いパスなので `.claude/settings.json` を共有リポジトリにコミットすると
  ホスト側の利用者で壊れます。`GRAPHIFYVERSION` を上げてパスが変わった場合も入れ直しが要ります。
- 同じコマンドの再実行で上書きされるので、やり直しは安全です。

## 主な使用例

- [hello-javascript/Dockerfile.dev.docker](https://github.com/uraitakahito/hello-javascript/blob/1.5.19/Dockerfile.dev.docker) — Docker / OrbStack 版
- [hello-javascript/Dockerfile.dev.container](https://github.com/uraitakahito/hello-javascript/blob/1.5.19/Dockerfile.dev.container) — Apple container 版

