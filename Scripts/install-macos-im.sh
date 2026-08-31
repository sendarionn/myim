#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
app_source="$repository_root/.build/myim.app"
app_destination="$HOME/Library/Input Methods/myim.app"
legacy_destination="$HOME/Library/Input Methods/my-ime.app"
was_registered=$(
    /usr/bin/swift \
        "$repository_root/Scripts/check-macos-input-source-registration.swift" \
        registered
)
was_selected=$(
    /usr/bin/swift \
        "$repository_root/Scripts/check-macos-input-source-registration.swift" \
        selected
)

"$repository_root/Scripts/build-macos-ime.sh"

mkdir -p "$HOME/Library/Input Methods"

if [[ "$was_selected" == "1" ]]; then
    /usr/bin/swift \
        "$repository_root/Scripts/check-macos-input-source-registration.swift" \
        select-fallback
fi

pkill -x myim 2>/dev/null || true
pkill -x my-ime 2>/dev/null || true
pkill -x myim-external-browser 2>/dev/null || true
for process_name in myim my-ime myim-external-browser; do
    for attempt in {1..20}; do
        if ! pgrep -x "$process_name" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
done
if [[ -d "$app_destination" ]]; then
    rm -rf "$app_destination"
fi
if [[ -d "$legacy_destination" ]]; then
    rm -rf "$legacy_destination"
fi
ditto "$app_source" "$app_destination"

if [[ "$was_registered" == "1" ]]; then
    if [[ "$was_selected" == "1" ]]; then
        restored=0
        for attempt in {1..20}; do
            if /usr/bin/swift \
                "$repository_root/Scripts/check-macos-input-source-registration.swift" \
                select-myim; then
                restored=1
                break
            fi
            sleep 0.1
        done
        if [[ "$restored" != "1" ]]; then
            echo "myim入力ソースへ戻せませんでした" >&2
            exit 1
        fi
    fi
    echo "登録済みの入力ソースを維持しました"
    echo "インストールしました: $app_destination"
    exit 0
fi

/usr/bin/swift -e '
import Carbon
import Foundation

let targetIdentifier = "io.github.sendarionn.inputmethod.myime.Japanese"
func findTargetSource() -> TISInputSource? {
    let sources = TISCreateInputSourceList(nil, true).takeRetainedValue()
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
        if identifier == targetIdentifier {
            return source
        }
    }
    return nil
}

var targetSource = findTargetSource()
let isFirstRegistration = targetSource == nil
if isFirstRegistration {
    let appURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Input Methods/myim.app") as CFURL
    let status = TISRegisterInputSource(appURL)
    guard status == noErr else {
        fatalError("入力ソースの登録に失敗しました: \(status)")
    }
    targetSource = findTargetSource()
}
guard let targetSource else {
    fatalError("登録後のmyim入力ソースが見つかりません")
}
if isFirstRegistration {
    let enableStatus = TISEnableInputSource(targetSource)
    guard enableStatus == noErr else {
        fatalError("入力ソースの有効化に失敗しました: \(enableStatus)")
    }
    let selectionStatus = TISSelectInputSource(targetSource)
    guard selectionStatus == noErr else {
        fatalError("入力ソースの選択に失敗しました: \(selectionStatus)")
    }
}
'

echo "インストールしました: $app_destination"
