#!/bin/zsh

set -euo pipefail

app_source=".build/my-ime.app"
app_destination="$HOME/Library/Input Methods/my-ime.app"

if [[ ! -d "$app_source" ]]; then
    echo "先に ./Scripts/build-macos-ime.sh を実行してください" >&2
    exit 1
fi

mkdir -p "$HOME/Library/Input Methods"
pkill -x my-ime 2>/dev/null || true
ditto "$app_source" "$app_destination"

/usr/bin/swift -e '
import Carbon
import Foundation

let appURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Input Methods/my-ime.app") as CFURL
let status = TISRegisterInputSource(appURL)
guard status == noErr else {
    fatalError("入力ソースの登録に失敗しました: \(status)")
}
'

open "$app_destination"
echo "インストールしました: $app_destination"
