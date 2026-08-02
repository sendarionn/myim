#!/bin/zsh

set -euo pipefail

app_source=".build/myim.app"
app_destination="$HOME/Library/Input Methods/myim.app"
legacy_destination="$HOME/Library/Input Methods/my-ime.app"

if [[ ! -d "$app_source" ]]; then
    echo "先に ./Scripts/build-macos-ime.sh を実行してください" >&2
    exit 1
fi

mkdir -p "$HOME/Library/Input Methods"

pkill -x myim 2>/dev/null || true
pkill -x my-ime 2>/dev/null || true
if [[ -d "$app_destination" ]]; then
    rm -rf "$app_destination"
fi
if [[ -d "$legacy_destination" ]]; then
    rm -rf "$legacy_destination"
fi
ditto "$app_source" "$app_destination"

/usr/bin/swift -e '
import Carbon
import Foundation

let appURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Input Methods/myim.app") as CFURL
let status = TISRegisterInputSource(appURL)
guard status == noErr else {
    fatalError("入力ソースの登録に失敗しました: \(status)")
}

let sources = TISCreateInputSourceList(nil, false).takeRetainedValue()
    as! [TISInputSource]
for source in sources {
    guard let pointer = TISGetInputSourceProperty(
        source,
        kTISPropertyInputSourceID
    ) else {
        continue
    }
    let identifier = Unmanaged<CFString>
        .fromOpaque(pointer)
        .takeUnretainedValue() as String
    if identifier == "io.github.sendarionn.inputmethod.myime.Japanese" {
        let selectionStatus = TISSelectInputSource(source)
        guard selectionStatus == noErr else {
            fatalError("入力ソースの選択に失敗しました: \(selectionStatus)")
        }
        break
    }
}
'

echo "インストールしました: $app_destination"
