#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
python3 "$repository_root/Scripts/download-emoji-assets.py"
xcrun swift "$repository_root/Scripts/normalize-emoji-assets.swift" \
    "$repository_root/Sources/MyIMEMacOS/Resources/Emoji/Android" \
    "$repository_root/Sources/MyIMEMacOS/Resources/Emoji/Windows"

echo "絵文字画像を更新しました"
