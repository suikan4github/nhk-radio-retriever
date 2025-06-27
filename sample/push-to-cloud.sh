#!/bin/sh

# 取得したファイルをクラウドにアップロードするサンプルスクリプト
# Usage: ./push-to-cloud.sh 
#
# このスクリプトは、nhk-radio-retrieverが取得した録音ファイルを
# Google Driveなどのクラウドストレージにアップロードします。
# その後、アップロードしたファイルをメールで通知します。
# 最後に、元のファイルは0バイトに切り詰め、30日後に削除します。
#
# 前提条件:
# - rcloneがインストールされていること
# - rcloneの設定が完了していること（Google Driveなどのクラウドストレージへのアクセスが設定されていること）
# - mailコマンドが使用可能であること（メール送信のため）

# cargoのパスの設定。
# cargoをrustの公式インストーラでインストールした場合は、以下が必要になる。
# Ubuntuのリポジトリからインストールした場合は不要。
export PATH="$HOME/.cargo/bin:$PATH"

# 録音ファイルのディレクトリ
RECORDING_DIR=~/recordings

# 現在のディレクトリがnhk-radio-retriever/sampleであることを前提としている。
cd ..
cargo run --release -q -- retrieve || {
    echo "Failed to retrieve recordings." | mail -s "Recording Retrieval Failed" root
    exit 1
} 

# 録音ファイル・ディレクトリに移動
cd "$RECORDING_DIR" || exit 1

# ファイルをアップロードする
# 結果はいずれもメールで報告する
# 成功した場合はファイルをtruncateする
find . -maxdepth 1 -type f -name "*.m4a" -size +0c | while read -r file; do
    if rclone copy "$file" gdrive:recordings/; then
        # 成功報告。URLはGoogle Driveのユーザー固有ディレクトリ
        echo "nhk-radio-retrieverで取得した $file をクラウドにアップロードしました. https://drive.google.com/drive/folders/1SE54Ee5l9JLUoK9be6jbWKbAv_54v9JS" | mail -s "成功：録音ファイルのアップロード" root
        truncate -s 0 "$file" # ファイルを0バイトにする
    else
        # 失敗報告
        echo "nhk-radio-retrieverで取得した $file をクラウドにアップロードできませんでした" | mail -s "失敗：録音ファイルのアップロード" root
    fi
done

# 作成して30日以上経過したファイルを削除する
# 報告は不要
find . -maxdepth 1 -type f -name "*.m4a" -mtime +30 -exec rm -f {} \;

