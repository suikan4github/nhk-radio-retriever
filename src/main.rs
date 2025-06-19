// このプログラムはNHKらじるらじるの聴き逃し配信の保存をおこなう。
// サブコマンドは3つある。
// 1. list: 番組の一覧を表示する
// 2. retrieve: 番組のストリームを保存する
// 3. generate-completions: コマンドライン補完のためのスクリプトを生成する
// retrieve サブコマンドでは保存したい番組のIDをJSON形式で指定する。
// list サブコマンドはそのための番組のIDを取得するために使用する。

use clap::{CommandFactory, Parser, Subcommand};
use clap_complete;

use serde::{Deserialize, Serialize};
use std::io::Write;

// コマンドライン引数の体系を定義する
#[derive(Subcommand, Debug)]
enum Command {
    /// 番組の一覧を表示する
    List {
        /// 番組の一覧をJSON形式で保存するファイルのパス
        #[arg(short, long, default_value = "available_program.json")]
        output_file: String,
    },
    /// 番組のストリームを保存する
    Retrieve {
        /// 保存したい番組のIDを格納したJSONファイルのパス
        #[arg(short, long, default_value = "program_to_save.json")]
        program_to_save: String,
        /// 保存先のディレクトリ
        #[arg(short, long, default_value = concat!(env!("HOME"), "/recordings"))]
        output_dir: String,
    },
    /// コマンドライン補完のためのスクリプトを生成する
    GenerateCompletions {
        /// シェルの種類
        #[arg(short, long, value_enum)]
        shell: clap_complete::Shell,
    },
}

// コマンドライン構造体
#[derive(Parser, Debug)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

fn main() {
    // コマンドライン引数を解析する
    let cli = Cli::parse();

    // サブコマンドに応じて処理を分岐する
    match cli.command {
        Command::List { output_file } => {
            // 番組の一覧を表示する処理
            list_programs(&output_file);
        }
        Command::Retrieve {
            program_to_save,
            output_dir,
        } => {
            // 番組のストリームを保存する処理
            retrieve_programs(&program_to_save, &output_dir);
        }
        Command::GenerateCompletions { shell } => {
            // コマンドライン補完のためのスクリプトを生成する処理
            let mut cmd = Cli::command(); // 次の行で使う
            clap_complete::generate(
                shell,                  // 使用するシェルの種類
                &mut cmd,               // コマンドの定義
                env!("CARGO_PKG_NAME"), // Cargo.tomlに書いたパッケージ名
                &mut std::io::stdout(), // 出力先
            );
        }
    }
}

// エピソード構造体を定義する
#[derive(Serialize, Deserialize, Debug)]
//#[allow(non_snake_case)]
struct Episode {
    id: u32,
    program_title: String,
    onair_date: String,
    stream_url: String,
    program_sub_title: String,
}

// シリーズ構造体を定義する
#[derive(Serialize, Deserialize, Debug)]
//#[allow(non_snake_case)]
struct Series {
    id: u32,
    title: String,
    episodes: Vec<Episode>,
}

// コーナー構造体を定義する
#[derive(Serialize, Deserialize, Debug)]
//#[allow(non_snake_case)]
struct Corner {
    title: String,
    corner_name: String,
    series_site_id: String,
    corner_site_id: String,
}

// 新着情報構造体を定義する
#[derive(Serialize, Deserialize, Debug)]
//#[allow(non_snake_case)]
struct NewInfo {
    corners: Vec<Corner>,
}

// 聴き逃し配信が存在する番組の一覧を取得してJSON形式で保存する関数
fn list_programs(output_file: &str) {
    // 番組の一覧を取得してJSON形式で保存する処理
    let source_url = "https://www.nhk.or.jp/radio-api/app/v1/web/ondemand/corners/new_arrivals";

    // source_urlを使用してAPIからデータを取得し、output_fileに保存する処理を実装する
    // reqwestをsyncで使用する。
    let response = reqwest::blocking::get(source_url).expect(&format!(
        "ソースURL {} へのアクセスを確立できるようにしてください。",
        source_url
    ));

    // JSONレスポンスをテキストとして取得する
    let body = response
        .text()
        .expect("正しいテキストファイルを取得できるURLを指定してください。");

    // 新着聴き逃し情報をデシリアライズする
    let new_info: NewInfo = serde_json::from_str(&body).expect("JSON was not well-formatted");

    // 書き込み先ファイルを開く
    let mut file = std::fs::File::create(output_file).expect(&format!(
        "ファイル {} を作成できませんでした。ディレクトリを確認してください。",
        output_file
    ));
    // 新着情報をJSON形式でファイルに書き込む
    // 各コーナーのtitle, corner_name,series_site_id, corner_site_id, を表示する
    writeln!(&mut file, "[").expect("ファイルへのJSON開始文字の書き込みに失敗しました。");
    for (index, corner) in new_info.corners.iter().enumerate() {
        write!(
            &mut file,
            r#"{{"title": "{}","corner_name": "{}","series_site_id": "{}","corner_site_id": "{}"}}"#,
            corner.title, corner.corner_name, corner.series_site_id, corner.corner_site_id
        ).expect("ファイルへのJSON情報の書き込みに失敗しました。");
        if index == new_info.corners.len() - 1 {
            // 最後の要素の場合はカンマを付けない
            writeln!(&mut file).expect("ファイルへのJSON改行の書き込みに失敗しました。");
        } else {
            // それ以外の場合はカンマを付ける
            writeln!(&mut file, ",").expect("ファイルへのJSONカンマの書き込みに失敗しました。");
        }
    }
    writeln!(&mut file, "]").expect("ファイルへのJSON終了文字の書き込みに失敗しました。");
}

// 番組に関するJSONをサーバーから取得して、聴き逃し配信のストリームを保存する関数。
// すでに保存したファイルについては、再度保存しない。
fn retrieve_programs(program_to_save: &str, output_dir: &str) {
    // 出力ディレクトリが存在しない場合は作成する
    if !std::path::Path::new(output_dir).exists() {
        std::fs::create_dir_all(output_dir).expect(&format!(
            "出力ディレクトリ {} を作成できませんでした。ディレクトリを確認してください。",
            output_dir
        ));
    }
    // Program to saveを開く。
    // これはユーザーが編集したJSONファイルで、保存したい番組のIDを含む。
    let file_content = std::fs::read_to_string(program_to_save).expect(
        format!(
            "指定された {} を読み込めませんでした。ファイル名とディレクトリを確認してください。",
            program_to_save
        )
        .as_str(),
    );
    // JSONをデシリアライズして、保存したい番組の情報を取得する。
    let programs: Vec<Corner> = serde_json::from_str(&file_content)
        .expect(format!("{}のフォーマットが正しくありません。", program_to_save).as_str());
    // 各コーナーの情報を表示する
    for program in programs {
        // 番組とコーナーごとのJSONのURL
        // すべての番組とコーナーはユニークなIDを持っており、そこから番組情報のURLを組み立てることができる。
        let series_url = format!(
            "https://www.nhk.or.jp/radio-api/app/v1/web/ondemand/series?site_id={}&corner_site_id={}",
            program.series_site_id, program.corner_site_id
        );
        // series_urlを使用してAPIから番組データを取得する。
        let response = reqwest::blocking::get(&series_url).expect(&format!(
            "番組URL {} へのアクセスを確立できるようにしてください。",
            series_url
        ));
        // JSONレスポンスをテキストとして取得する
        // ここで失敗することは、まぁ無い。
        let body = response.text().expect(
            format!(
                "URL {} から正しいテキストファイルを取得できるようにしてください。",
                series_url
            )
            .as_str(),
        );
        // シリーズ情報をデシリアライズする
        let series: Series = serde_json::from_str(&body).expect(
            format!(
                "サーバーから取得したJSON {} が正しくありません。",
                series_url
            )
            .as_str(),
        );
        // 各エピソードの情報を処理する
        for episode in series.episodes {
            // idとprogram_titleからエピソードに対応する出力ファイル名を作る。
            let episode_filename = format!(
                "{}/{}_{}.m4a",
                output_dir,
                episode.id,
                episode.program_title.replace(" ", "_")
            )
            .replace("//", "/"); // 余分なディレクトリ記号を削除
                                 // エピソードファイルが存在しないなら、stream_urlからストリームを保存する。
            if !std::path::Path::new(&episode_filename).exists() {
                // gst-launch-1.0 コマンドを構築
                let mut child = std::process::Command::new("gst-launch-1.0")  
                    .arg("souphttpsrc")// souphttpsrc uses libsoup to get resources from HTTP.
                    .arg(format!("location={}", &episode.stream_url))
                    .arg("!")
                    .arg("hlsdemux")   // Then, demux the HLS stream.
                    .arg("!")
                    .arg("aacparse")   // And then, parse the AAC audio stream.
                    .arg("!")
                    .arg("mp4mux")     // And then, mux it into MP4 format.
                    .arg("!")
                    .arg("filesink")   // And then, write it to a file.
                    .arg(format!("location={}", episode_filename))
                    .arg("sync=false")
                    .arg("async=false")
                    .stdout(if cfg!(unix) { std::process::Stdio::null() } else { std::process::Stdio::inherit() }) // 標準出力を無視
                    .spawn()
                    .expect("gst-launch-1.0の起動に失敗しました。gst-launch-1.0がインストールされていることを確認してください。");

                let _ = child
                    .wait()
                    .expect("gst-launch-1.0のプロセスが正常に終了しませんでした。");
            }
        }
    }
}
