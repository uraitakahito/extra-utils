## 概要

Docker 開発コンテナ向けの追加ユーティリティインストーラー。公式の [features](https://github.com/uraitakahito/features) と組み合わせ、Claude Code を含む開発環境を構築するための補助パッケージ群を提供します。

## 開発時の動作確認手順

[hello-javascript](https://github.com/uraitakahito/hello-javascript) の開発用
Dockerfile を取得して使います。ランタイムごとに 2 本あるので、使う方を選んでください。

```bash
BASE=https://raw.githubusercontent.com/uraitakahito/hello-javascript/refs/tags/1.5.18

# Docker / OrbStack の場合
curl -L -O "$BASE/Dockerfile.dev.docker"

# Apple container の場合
curl -L -O "$BASE/Dockerfile.dev.container"

curl -L -O "$BASE/docker-entrypoint.sh"
chmod 755 docker-entrypoint.sh
```

続きの手順はDockerfile内のコメントを参照してください。

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
- **スキル登録はイメージに含めていません。** ホームやカレントディレクトリを書き換える操作で、
  ビルド時に root で実行しても利用者には効かないためです。コンテナ内で 1 度実行してください:

  ```sh
  graphify install            # ユーザプロファイルへ登録
  graphify install --project  # カレントのリポジトリへ登録
  ```

## 主な使用例

- [hello-javascript/Dockerfile.dev.docker](https://github.com/uraitakahito/hello-javascript/blob/1.5.18/Dockerfile.dev.docker) — Docker / OrbStack 版
- [hello-javascript/Dockerfile.dev.container](https://github.com/uraitakahito/hello-javascript/blob/1.5.18/Dockerfile.dev.container) — Apple container 版

