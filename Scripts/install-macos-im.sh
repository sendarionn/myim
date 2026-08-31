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
    fallback_selected=0
    for attempt in {1..20}; do
        fallback_selected=$(
            /usr/bin/swift \
                "$repository_root/Scripts/check-macos-input-source-registration.swift" \
                selected-fallback
        )
        if [[ "$fallback_selected" == "1" ]]; then
            break
        fi
        sleep 0.1
    done
    if [[ "$fallback_selected" != "1" ]]; then
        echo "ABC入力ソースへの切り替えを確認できませんでした" >&2
        exit 1
    fi
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
"$app_destination/Contents/MacOS/myim" --register-input-source

if [[ "$was_registered" == "1" ]]; then
    if [[ "$was_selected" == "1" ]]; then
        restored=0
        for attempt in {1..20}; do
            /usr/bin/swift \
                "$repository_root/Scripts/check-macos-input-source-registration.swift" \
                select-myim || true
            sleep 0.1
            selected=$(
                /usr/bin/swift \
                    "$repository_root/Scripts/check-macos-input-source-registration.swift" \
                    selected
            )
            if [[ "$selected" == "1" ]]; then
                restored=1
                break
            fi
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

"$app_destination/Contents/MacOS/myim" --enable-input-source
/usr/bin/swift \
    "$repository_root/Scripts/check-macos-input-source-registration.swift" \
    select-myim

echo "インストールしました: $app_destination"
