#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
checkout="$repository_root/.build/checkouts/AzooKeyKanaKanjiConverter"
patch_file="$repository_root/Patches/azookey-macos-app-resources.patch"

swift package --package-path "$repository_root" resolve

if git -C "$checkout" apply --reverse --check "$patch_file" 2>/dev/null; then
    exit 0
fi

git -C "$checkout" apply --check "$patch_file"
git -C "$checkout" apply "$patch_file"
