# nhk-radio-retriever
NHKの聴き逃し配信をチェックして、指定された番組のコンテンツを保存します。

# 詳細

このプログラムは、NHKらじるらじるの聴き逃し配信をチェックし、JSON形式で指定した番組のコンテンツをm4a形式で保存します。
すでに保存した番組については再保存はしません。


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

プログラムの動作確認はLinuxで行っています。プログラム自体のOS依存性は小さいですが、
サブプロセスとしてGStreamerを使っているため、Linux以外で動かすのは難しいでしょう。

以下の環境で動作を確認しています。
- Ubuntu 24.04 LTS (WSL2)
- Debian 12
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
list サブコマンドを使用して、NHKの聴き逃し配信番組の一覧を取得できます。
```sh
cargo run -- list
```
特に指定しない場合、カレントディレクトリの`available_program.json`に番組の一覧が保存されます。JSONファイル形式は以下のようになっています。

```json:available_program.json
[
{"title": "FM能楽堂","corner_name": "","series_site_id": "BWK24VXYWW","corner_site_id": "01"},
{"title": "弾き語りフォーユー","corner_name": "","series_site_id": "ZG79L367QZ","corner_site_id": "01"},
{"title": "名曲スケッチ","corner_name": "","series_site_id": "K7NR257MJ5","corner_site_id": "01"},
{"title": "音楽遊覧飛行","corner_name": "","series_site_id": "2QVV8Q6LV2","corner_site_id": "01"},
...
]
```
このJSONファイルは、番組のタイトル、コーナー名、シリーズサイトID、コーナーサイトIDを含んでいます。

JSONファイルのパスを指定することもできます。
```sh
cargo run -- list --output-file /path/to/your/available_program.json
```
`--output-file`オプションを使用して、出力先のファイルを指定できます。
## 保存したい番組の指定
番組のタイトルを頼りに、保存したい番組を選び、それ以外の行を削除してください。

そうして、出来上がったJSONファイルを`program_to_save.json`という名前で保存してください。
```json:program_to_save.json
[
{"title": "名曲スケッチ","corner_name": "","series_site_id": "K7NR257MJ5","corner_site_id": "01"},
{"title": "音楽遊覧飛行","corner_name": "","series_site_id": "2QVV8Q6LV2","corner_site_id": "01"}
]
```
JSONファイルの規則に沿っていれば、改行やインデントは自由です。

## 番組の保存
`program_to_save.json`はカレントディレクトリにおいてください。
次に、retrieve サブコマンドを使用して、指定した番組のコンテンツを保存します。
```sh
cargo run -- retrieve
```
取得した音楽ファイルは、`~/recordings`ディレクトリに保存されます。

ファイルの名前は番組名と一意な番号の組み合わせになっています。
既に存在するファイルは再取得されません。

`program_to_save.json`のパスや、音楽ファイルの保存先を変更したい場合は、以下のようにオプションを指定できます。

```sh
cargo run -- retrieve --program-to-save /path/to/your/program_to_save.json --output-dir /path/to/your/recordings
```
`--program-to-save`オプションで番組のJSONファイルのパスを、`--output-dir`オプションで保存先ディレクトリを指定できます。

# ライセンス
このプログラムは[MITライセンス](LICENSE)の下で公開されています。
