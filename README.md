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
サブプロセスとしてGStreamerを使っているため、Linux以外のOSで動くか否かについては何とも言えません。。

以下の環境で動作を確認しています。
- Debian 13 (trixie)
- 最新の安定版Rustツールチェーン

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

## debパッケージによるインストール
`cargo-deb`を使うと、`nhk-radio-retriever`と定期実行用のスクリプト、systemdのタイマーを
1つのdebパッケージにまとめられます。

```sh
cargo install cargo-deb
cargo deb
sudo apt install ./target/debian/nhk-radio-retriever_*.deb
```

パッケージには次のファイルが含まれます。パッケージ用のファイルは[deb/](deb)ディレクトリにあります。

| インストール先 | 内容 |
|---|---|
| `/usr/bin/nhk-radio-retriever` | 本体 |
| `/usr/bin/nhk-radio-push-to-cloud` | 録音を取得してクラウドにアップロードするスクリプト（[deb/push-to-cloud.sh](deb/push-to-cloud.sh)） |
| `/etc/default/nhk-radio-retriever` | スクリプトの設定ファイル |
| `nhk-radio-retriever.service` / `nhk-radio-retriever.timer` | systemdのサービスとタイマー |

インストールすると、専用のシステムユーザー`nhk-radio`（ホームは`/var/lib/nhk-radio-retriever`）が作成され、
タイマーが有効になります。タイマーは**毎日ローカル時刻の午前3時**に、このユーザーの権限でスクリプトを実行します。
電源が切れていて実行できなかった場合は、起動後に実行されます。

### インストール後の設定
タイマーは有効になりますが、次の設定をするまでスクリプトは正常に動作しません。

1. `/etc/default/nhk-radio-retriever`を編集します。

   | 変数 | 必須 | 内容 |
   |---|---|---|
   | `MTA_ADDRESS` | 必須 | 結果通知メールを送るSMTPサーバーのアドレス（例: `smtp.example.com`） |
   | `STORAGE_URL` | 必須 | 通知メールに記載するクラウドストレージのURL |
   | `REMOTE_DIR` | 任意 | アップロード先のディレクトリ。省略時は`nhk_radio/` |

2. rcloneをインストールします。Debianのパッケージは古いため、公式のインストールスクリプトを使います。
   事前に`curl`が必要です（debパッケージの依存には含めていません）。
   ```sh
   sudo apt install curl unzip
   curl https://rclone.org/install.sh | sudo bash
   ```

3. 専用ユーザーでrcloneを設定します。
   なお、インストール先がヘッドレスサーバーの場合、SSHトンネルを使って手元のPCで認証を行う必要があります。SSHトンネルを有効にするため、次のコマンドでSSH接続しておいてください。
   ```sh
   ssh -L 53682:localhost:53682 <ユーザー名>@<ヘッドレスサーバーのホスト名またはIPアドレス>
   ```

   次にrcloneの設定を行います。
   リモート名は**`nhk_radio`**にしてください。
   サービスの種類（OneDrive、Google Driveなど）はリモートの`type`で決まるので、
   スクリプトを変更せずに切り替えられます。
   ```sh
   sudo -u nhk-radio -H rclone config
   ```
   ブラウザのない環境でOAuth認証が必要な場合は、手元のPCで`rclone authorize "onedrive"`などを実行し、
   表示されたトークンを`rclone config`に貼り付けます。

4. 保存したい番組を指定する`program_to_save.json`を、専用ユーザーの設定ディレクトリに置きます。
   作り方は後述の「保存したい番組の指定」を参照してください。
   ```sh
   sudo -u nhk-radio -H mkdir -p /var/lib/nhk-radio-retriever/.config/nhk-radio-retriever
   sudo -u nhk-radio -H nhk-radio-retriever list
   ```
   `list`で作られた`available_program.json`から不要な行を削除し、
   `/var/lib/nhk-radio-retriever/.config/nhk-radio-retriever/program_to_save.json`として保存します。

以上の設定により、毎日午前3時に`push-to-cloud.sh`スクリプトが実行され、ストリームを保存さ、クラウドにアップロードされます。

午前3時を待たずに即座にスクリプトを実行したい場合は、次のコマンドを使用します。
```sh
sudo systemctl start --no-block nhk-radio-retriever.service  # 手動でpush-to-cloud.shを実行
```

上のコマンドでスクリプトを手動実行した後、次のコマンドでタイマーの状態や結果のログを確認できます。
なお、スクリプトがリトライした場合、結果が出るまで最大30分程度かかることがあります。

```
systemctl list-timers nhk-radio-retriever.timer    # 次回の実行予定
journalctl -t push-to-cloud                        # スクリプトのログ
```

### スクリプトの動作
`nhk-radio-push-to-cloud`は次の順に処理します。
1. `nhk-radio-retriever retrieve`で番組を取得します。失敗した場合は15分間隔で最大3回まで試行し、
   すべて失敗するとメールで通知して終了します。
2. `rclone copy`で録音ファイルをクラウドにアップロードします。こちらも失敗した場合は15分間隔で最大3回まで試行します。
   成否はメールで通知します。
3. 作成から30日以上経過した`.m4a`ファイルを、アップロードの成否にかかわらず削除します。

エラーや再試行の記録は、`journalctl -t push-to-cloud`で確認できます。
メール送信には`mailx`コマンドを使います。`--exec`オプションを使っているため、
お使いの`mailx`の実装が対応していない場合は、スクリプトを調整してください。


# 利用方法

## 聞き逃し配信番組リストの取得
list サブコマンドを使用して、NHKの聴き逃し配信番組の一覧を取得できます。聴き逃し番組のリストは番組更改ごとに更新される可能性があります。
```sh
cargo run -- list
```
特に指定しない場合、`$HOME/.config/nhk-radio-retriever/available_program.json`に番組の一覧が保存されます。JSONファイル形式は以下のようになっています。

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
保存先は`$HOME/.config/nhk-radio-retriever/`です。
```json:program_to_save.json
[
{"title": "名曲スケッチ","corner_name": "","series_site_id": "K7NR257MJ5","corner_site_id": "01"},
{"title": "音楽遊覧飛行","corner_name": "","series_site_id": "2QVV8Q6LV2","corner_site_id": "01"}
]
```
JSONファイルの規則に沿っていれば、改行やインデントは自由です。

## 番組の保存
`program_to_save.json`は`$HOME/.config/nhk-radio-retriever/`においてください。
次に、retrieve サブコマンドを使用して、指定した番組のコンテンツを保存します。
```sh
cargo run -- retrieve
```
取得した音楽ファイルは、`$HOME/.local/share/nhk-radio-retriever/recordings`ディレクトリに保存されます。

ファイルの名前は番組名と一意な番号の組み合わせになっています。
既に存在するファイルは再取得されません。

`program_to_save.json`のパスや、音楽ファイルの保存先を変更したい場合は、以下のようにオプションを指定できます。

```sh
cargo run -- retrieve --program-to-save /path/to/your/program_to_save.json --output-dir /path/to/your/recordings
```
`--program-to-save`オプションで番組のJSONファイルのパスを、`--output-dir`オプションで保存先ディレクトリを指定できます。

# ライセンス
このプログラムは[MITライセンス](LICENSE)の下で公開されています。
