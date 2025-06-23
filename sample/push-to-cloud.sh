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

cd "$RECORDING_DIR" || exit 1
# Find all new .m4a files which is larger than 0 byte and copy them to the cloud.
find . -maxdepth 1 -type f -name "*.m4a" -size +0c -exec rclone copy {} gdrive:recordings/ \; -exec echo "Copied {} to cloud." | mail -s "Recording Copied" root \; 

# Truncate the original files to 0 byte.
find . -maxdepth 1 -type f -name "*.m4a" -size +0c -exec truncate -s 0 {} \;

