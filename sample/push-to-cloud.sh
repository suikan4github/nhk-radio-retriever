#!/bin/sh

# Sample script to push a file to the cloud.
# Usage: ./push-to-cloud.sh 
#
# This script copies all new *.m4a files in ~/recordings.
# And for each file, it report to root by email. 
# Finally, original copied files are truncated to size 0 byte. 
# 
# Ensure you have the necessary permissions and configurations set up for your cloud service with rclone.

# Set the recording directory.
RECORDING_DIR=~/recordings

# Assume the current directory is sample directory.
cd ..
cargo run --release -- retrieve || {
    echo "Failed to retrieve recordings." | mail -s "Recording Retrieval Failed" root
    exit 1
} 

# 録音ファイル・ディレクトリに移動
cd "$RECORDING_DIR" || exit 1

# アップロードしたファイル名を一時ファイルに記録
TMPFILE=$(mktemp)
find . -maxdepth 1 -type f -name "*.m4a" -size +0c | while read -r file; do
    if rclone copy "$file" remote:recordings/; then
        echo "Successfully copied $file to the cloud." | mail -s "Recording Upload Success" root
        echo "$file" >> "$TMPFILE"
    else
        echo "Failed to copy $file to the cloud." | mail -s "Recording Upload Failed" root
    fi
done

# アップロード成功したファイルだけtruncate
if [ -s "$TMPFILE" ]; then
    while read -r file; do
        truncate -s 0 "$file"
    done < "$TMPFILE"
fi

# Clean up the temporary file
rm -f "$TMPFILE"




