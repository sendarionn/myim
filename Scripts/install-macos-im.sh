#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
app_source="$repository_root/.build/myim.app"
input_methods_directory="$HOME/Library/Input Methods"
app_destination="$input_methods_directory/myim.app"
staged_destination="$input_methods_directory/.myim.installing.app"
previous_destination="$input_methods_directory/.myim.previous.app"
legacy_destination="$input_methods_directory/my-ime.app"

status_value() {
    local executable=$1
    local key=$2
    "$executable" --input-source-status 2>/dev/null \
        | awk -F= -v key="$key" '$1 == key { print $2 }'
}

wait_for_status() {
    local executable=$1
    local key=$2
    local expected=$3
    local attempt
    for attempt in {1..30}; do
        if [[ "$(status_value "$executable" "$key")" == "$expected" ]]; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

stop_process() {
    local process_name=$1
    local attempt
    pkill -x "$process_name" 2>/dev/null || true
    for attempt in {1..30}; do
        if ! pgrep -x "$process_name" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    echo "$process_name を終了できませんでした" >&2
    return 1
}

cleanup_staging() {
    [[ ! -e "$staged_destination" ]] || rm -rf "$staged_destination"
}

restore_previous_application() {
    [[ -e "$previous_destination" ]] || return 0
    mkdir -p "$app_destination"
    /usr/bin/rsync -aE --delete \
        "$previous_destination/" \
        "$app_destination/"
}

"$repository_root/Scripts/build-macos-ime.sh"

source_executable="$app_source/Contents/MacOS/myim"
was_registered=$(status_value "$source_executable" registered)
was_selected=$(status_value "$source_executable" selected)

if [[ "$was_selected" == "1" ]]; then
    "$source_executable" --select-fallback-input-source
    wait_for_status "$source_executable" fallback-selected 1
fi

stop_process myim
stop_process my-ime
stop_process myim-external-browser

mkdir -p "$input_methods_directory"
cleanup_staging
trap cleanup_staging EXIT
ditto "$app_source" "$staged_destination"
codesign --verify --deep --strict "$staged_destination"

[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
if [[ -e "$app_destination" ]]; then
    ditto "$app_destination" "$previous_destination"
    /usr/bin/rsync -aE --delete \
        "$staged_destination/" \
        "$app_destination/"
else
    mkdir -p "$app_destination"
    /usr/bin/rsync -aE \
        "$staged_destination/" \
        "$app_destination/"
fi
if ! codesign --verify --deep --strict "$app_destination"; then
    restore_previous_application
    echo "myim.app の検証に失敗したため旧版へ戻しました" >&2
    exit 1
fi
cleanup_staging
[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
[[ ! -e "$legacy_destination" ]] || rm -rf "$legacy_destination"

installed_executable="$app_destination/Contents/MacOS/myim"
"$installed_executable" --register-input-source
"$installed_executable" --enable-input-source
wait_for_status "$installed_executable" registered 1
wait_for_status "$installed_executable" enabled 1

if [[ "$was_selected" == "1" || "$was_registered" != "1" ]]; then
    "$installed_executable" --select-input-source
    wait_for_status "$installed_executable" selected 1
fi

trap - EXIT
echo "インストールしました: $app_destination"
