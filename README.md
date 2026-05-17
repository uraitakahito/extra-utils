## 概要

Docker 開発コンテナ向けの追加ユーティリティインストーラー。公式の [features](https://github.com/uraitakahito/features) と組み合わせ、Claude Code を含む開発環境を構築するための補助パッケージ群を提供します。

## 開発時の動作確認手順

```bash
curl -L -O https://raw.githubusercontent.com/uraitakahito/hello-javascript/refs/tags/1.2.7/Dockerfile.dev
curl -L -O https://raw.githubusercontent.com/uraitakahito/hello-javascript/refs/tags/1.2.7/docker-entrypoint.sh
chmod 755 docker-entrypoint.sh
```

続きの手順はDockerfile内のコメントを参照してください。

## 主な使用例

- [hello-javascript/Dockerfile.dev](https://github.com/uraitakahito/hello-javascript/blob/62e238f278fe989283b9b47b17c04283b6bdab9a/Dockerfile.dev)

