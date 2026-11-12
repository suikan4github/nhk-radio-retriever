#!/bin/sh

# 取得したファイルをクラウドにアップロードするサンプルスクリプト
# Usage: ./push-to-cloud.sh 
#
# このスクリプトは、nhk-radio-retrieverが取得した録音ファイルを
# Google Driveなどのクラウドストレージにアップロードします。
# その後、アップロード結果をメールで通知します。
# 最後に、元のファイルはアップロードの成否にかかわらず30日後に削除します。
#
# 前提条件:
# - nhk-radio-retrieverへのパスが通っていること
# - rcloneがインストールされていること
# - rcloneの設定が完了していること（Google Driveなどのクラウドストレージへのアクセスが設定されていること）
# - swaksコマンドが使用可能であること（メール送信のため）
# - MAIL_RECIPIENT環境変数に通知メールの宛先を設定しておくこと（例: user@example.com）
# - MTA_ADDRESS環境変数にSMTPサーバーのアドレスを設定しておくこと（例: smtp.example.com）
# - STORAGE_URL環境変数にクラウドストレージのURLを設定しておくこと（例: https://drive.google.com/drive/folders/xxx） 
#   このURLはメールを受け取ったユーザーが、アップロード先のクラウドストレージにアクセスできるようにするためのURLである。
# - オプションとしてREMOTE_DIR環境変数にクラウドストレージ上のディレクトリを設定しておくこと。（デフォルト: nhk_radio/）

# MTA_ADDRESS環境変数が未設定ならば、エラーとして終了する
# MAIL_RECIPIENT環境変数が未設定ならば、エラーとして終了する
# STORAGE_URL環境変数が未設定ならば、エラーとして終了する
# これらのエラーログは、`journalctl -t push-to-cloud` で確認できる。
if [ -z "${MTA_ADDRESS:-}" ] ; then
    echo "MTA_ADDRESS environment variable is not set" \
        | logger -t push-to-cloud -p user.err -s
    exit 1
fi
if [ -z "${MAIL_RECIPIENT:-}" ]; then
    echo "MAIL_RECIPIENT environment variable is not set" \
        | logger -t push-to-cloud -p user.err -s
    exit 1
fi
if [ -z "${STORAGE_URL:-}" ]; then
    echo "STORAGE_URL environment variable is not set" \
        | logger -t push-to-cloud -p user.err -s
    exit 1
fi

send_mail() {
    subject=$1
    body=$2
    encoded_subject=$(printf '%s' "$subject" | base64 -w 0) || return 1
    encoded_body=$(printf '%s' "$body" | base64 -w 76) || return 1

    if printf '%s\n' "$encoded_body" | swaks --silent \
            --server "$MTA_ADDRESS" --port 25 --to "$MAIL_RECIPIENT" \
            --header "Subject: =?UTF-8?B?${encoded_subject}?=" \
            --header "Content-Type: text/plain; charset=UTF-8" \
            --header "Content-Transfer-Encoding: base64" \
            --body @-; then
        return 0
    else
        status=$?
    fi

    echo "swaks failed to send notification email (exit ${status})" \
        | logger -t push-to-cloud -p user.err -s
    return "$status"
}

# 録音ファイルのディレクトリは ~/.local/share/nhk-radio-retriever/recordings/
RECORDING_DIR="$HOME/.local/share/nhk-radio-retriever/recordings/"

# nhk-radio-retrieverへのパスが通っていることを前提としている。
# 録音ファイルは、デフォルトで $HOME/.local/share/nhk-radio-retriever/recordings/ に保存される
# 失敗した場合は15分間隔で、成功するまで最大3回試行する。
MAX_ATTEMPTS=3
RETRY_INTERVAL=900
attempt=1
until nhk-radio-retriever retrieve; do
    echo "nhk-radio-retriever retrieve failed (attempt ${attempt}/${MAX_ATTEMPTS})" \
        | logger -t push-to-cloud -p user.warning -s
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
        send_mail "Recording Retrieval Failed" \
            "Failed to retrieve recordings by nhk-radio-retriever."
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep "$RETRY_INTERVAL"
done


# ファイルをアップロードする
# 結果はいずれもメールで報告する

# 失敗した場合は15分間隔で、成功するまで最大3回試行する。
upload_ok=0
attempt=1
while :; do
    if rclone sync "${RECORDING_DIR}" nhk_radio:"${REMOTE_DIR:-nhk_radio/}"; then
        upload_ok=1
        break
    fi
    echo "rclone copy failed (attempt ${attempt}/${MAX_ATTEMPTS})" \
        | logger -t push-to-cloud -p user.warning -s
    [ "$attempt" -ge "$MAX_ATTEMPTS" ] && break
    attempt=$((attempt + 1))
    sleep "$RETRY_INTERVAL"
done

if [ "$upload_ok" -eq 1 ]; then
    # 成功報告。URLはGoogle Driveのユーザー固有ディレクトリ
    send_mail "成功：録音ファイルのアップロード" \
        "nhk-radio-retrieverで取得した録音ファイルをクラウドにアップロードしました. ${STORAGE_URL}"
else
    # 失敗報告
    send_mail "失敗：録音ファイルのアップロード" \
        "nhk-radio-retrieverで取得した録音ファイルをクラウドにアップロードできませんでした"
fi


# 作成して30日以上経過したファイルを、アップロードの成否にかかわらず削除する。
# 失敗後も放置しておくと、ディスク容量を圧迫する可能性があるため、30日後に削除する。
find "$RECORDING_DIR" -maxdepth 1 -type f -name "*.m4a" -mtime +30 -exec rm -f {} \;
