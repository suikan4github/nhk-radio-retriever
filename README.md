# nhk-radio-retriever
NHKの聴き逃し配信をチェックして、指定された番組のコンテンツを保存します。

# 詳細

このプログラムは、NHKらじるらじるの聴き逃し配信をチェックし、JSON形式で指定した番組のコンテンツをm4a形式で保存します。
すでに保存した番組については再保存はしません。
この判断は保存ファイルの有無で行います。

コマンドラインから`--help`オプションを指定すると、利用可能なコマンドの一覧が表示されます。

```sh
$ nhk-radio-retriever --help
Usage: nhk-radio-retriever <COMMAND>

Commands:
  list                  番組の一覧を表示する
  retrieve              番組のストリームを保存する
  generate-completions  コマンドライン補完のためのスクリプトを生成する
  help                  Print this message or the help of the given subcommand(s)

Options:
  -h, --help     Print help
  -V, --version  Print version
```

プログラムの動作確認はLinuxで行っていますが、他のOSでも動作するかもしれません。
- Ubuntu 24.04 LTS
- Cargo 1.86.0

# インストール方法
Ubuntu 24.04 LTSでのインストール方法を示します。

最初に、必要なパッケージを取得します。
```sh
sudo apt install git cargo gstreamer1.0-plugins-bad gstreamer1.0-tools
```
gstreamerはメディア信号処理パイプラインですが、ここでは与えられたストリームのURLから
m4a形式のファイルを抽出して保存するために使用します。

次にプロジェクトを取得します。
```sh
git clone https://gihub.com/suikan4github/nhk-radio-retriever.git
cd nhk-radio-retriever
```

最後に、プロジェクトをビルドします。
```sh
cargo build
```


# 利用方法

## 聞き逃し配信番組リストの取得

## 保存したい番組の指定

## 番組の保存

## シェル補完

# ライセンス