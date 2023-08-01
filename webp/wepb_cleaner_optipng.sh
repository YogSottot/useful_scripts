#!/usr/bin/env bash
set -xeuo pipefail

doc_root=/home/bitrix/www/ || exit
cd "${doc_root}"/upload/resize_cache/webp/upload/iblock/
# Set the directories
original_dir="../../../../iblock/"
webp_dir="."


# Find and delete the webp files that have no corresponding original png/jpg files
find "$webp_dir" -type f -iname "*.webp" -print0 | while IFS= read -r -d $'\0' webp_file; do
    # Extract the relative path of the webp file
    #webp_relative_path="${webp_file#$webp_dir/}"
    
    # Remove the ".webp" extension from the webp file
    original_file="${webp_file%.webp}"
    
    # Check if the original png/jpg file exists
    if [ ! -f "$original_dir/$original_file.png" ] && [ ! -f "$original_dir/$original_file.jpg" ]; then
        echo "Deleting $webp_file"
        #rm "$webp_file"
    fi
done
