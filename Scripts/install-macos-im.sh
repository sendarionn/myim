#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
app_source="$repository_root/.build/myim.app"
selection_service_source="$repository_root/.build/myim-selection.service"
input_methods_directory="$HOME/Library/Input Methods"
services_directory="$HOME/Library/Services"
app_destination="$input_methods_directory/myim.app"
selection_service_destination="$services_directory/myim-selection.service"
staged_destination="$input_methods_directory/.myim.installing.app"
staged_selection_service="$services_directory/.myim-selection.installing.service"
previous_destination="$input_methods_directory/.myim.previous.app"
previous_selection_service="$services_directory/.myim-selection.previous.service"
legacy_destination="$input_methods_directory/my-ime.app"
launch_services_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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

wait_for_running_server() {
    local expected_executable=$1
    local attempt
    local process_id
    local confirmed_process_id=""
    local stable_checks=0
    for attempt in {1..100}; do
        process_id=$(pgrep -x myim 2>/dev/null | head -n 1 || true)
        if [[ -n "$process_id" ]] \
            && [[ "$(ps -p "$process_id" -o command= 2>/dev/null)" == "$expected_executable" ]]; then
            if [[ "$process_id" == "$confirmed_process_id" ]]; then
                stable_checks=$((stable_checks + 1))
            else
                confirmed_process_id=$process_id
                stable_checks=1
            fi
            if (( stable_checks >= 3 )); then
                return 0
            fi
        else
            confirmed_process_id=""
            stable_checks=0
        fi
        sleep 0.1
    done
    echo "新しいmyimプロセスの起動を確認できませんでした" >&2
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
    [[ ! -e "$staged_selection_service" ]] \
        || rm -rf "$staged_selection_service"
}

restore_previous_application() {
    [[ -e "$previous_destination" ]] || return 0
    mkdir -p "$app_destination"
    /usr/bin/rsync -aE --delete \
        "$previous_destination/" \
        "$app_destination/"
}

restore_previous_selection_service() {
    [[ -e "$previous_selection_service" ]] || return 0
    mkdir -p "$selection_service_destination"
    /usr/bin/rsync -aE --delete \
        "$previous_selection_service/" \
        "$selection_service_destination/"
}

installed_build_number=0
if [[ -f "$app_destination/Contents/Info.plist" ]]; then
    installed_build_number=$(
        /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
            "$app_destination/Contents/Info.plist" 2>/dev/null || echo 0
    )
fi
if [[ "$installed_build_number" != <-> ]]; then
    installed_build_number=0
fi
source_build_number=$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
        "$repository_root/macOS/Info.plist" 2>/dev/null || echo 0
)
if [[ "$source_build_number" != <-> ]]; then
    source_build_number=0
fi
base_build_number=$((
    installed_build_number > source_build_number
        ? installed_build_number
        : source_build_number
))
next_build_number=$((base_build_number + 1))
MYIM_BUILD_NUMBER="$next_build_number" \
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
stop_process myim-extension-host
stop_process myim-selection-service

mkdir -p "$input_methods_directory" "$services_directory"
cleanup_staging
trap cleanup_staging EXIT
ditto "$app_source" "$staged_destination"
codesign --verify --deep --strict "$staged_destination"
ditto "$selection_service_source" "$staged_selection_service"
codesign --verify --deep --strict "$staged_selection_service"

[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
[[ ! -e "$previous_selection_service" ]] \
    || rm -rf "$previous_selection_service"
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
if [[ -e "$selection_service_destination" ]]; then
    ditto \
        "$selection_service_destination" \
        "$previous_selection_service"
    /usr/bin/rsync -aE --delete \
        "$staged_selection_service/" \
        "$selection_service_destination/"
else
    mkdir -p "$selection_service_destination"
    /usr/bin/rsync -aE \
        "$staged_selection_service/" \
        "$selection_service_destination/"
fi
if ! codesign --verify --deep --strict "$app_destination"; then
    restore_previous_application
    echo "myim.app の検証に失敗したため旧版へ戻しました" >&2
    exit 1
fi
if ! codesign --verify --deep --strict "$selection_service_destination"; then
    restore_previous_selection_service
    echo "myim-selection.service の検証に失敗したため旧版へ戻しました" >&2
    exit 1
fi
cleanup_staging
[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
[[ ! -e "$previous_selection_service" ]] \
    || rm -rf "$previous_selection_service"
[[ ! -e "$legacy_destination" ]] || rm -rf "$legacy_destination"

installed_executable="$app_destination/Contents/MacOS/myim"
if ! cmp -s "$source_executable" "$installed_executable"; then
    restore_previous_application
    echo "インストール先のmyimバイナリがビルド結果と一致しません" >&2
    exit 1
fi
source_selection_service_executable="$selection_service_source/Contents/MacOS/myim-selection-service"
installed_selection_service_executable="$selection_service_destination/Contents/MacOS/myim-selection-service"
if ! cmp -s \
    "$source_selection_service_executable" \
    "$installed_selection_service_executable"; then
    restore_previous_selection_service
    echo "インストール先のSelection Serviceがビルド結果と一致しません" >&2
    exit 1
fi
installed_build_number=$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
        "$app_destination/Contents/Info.plist"
)
if [[ "$installed_build_number" != "$next_build_number" ]]; then
    restore_previous_application
    echo "myim.app のビルド番号が更新されていません" >&2
    exit 1
fi
installed_selection_service_build_number=$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
        "$selection_service_destination/Contents/Info.plist"
)
if [[ "$installed_selection_service_build_number" != "$next_build_number" ]]; then
    restore_previous_selection_service
    echo "myim-selection.service のビルド番号が更新されていません" >&2
    exit 1
fi
"$installed_executable" --install-default-extensions
"$launch_services_register" -u "$app_source" 2>/dev/null || true
"$launch_services_register" -u "$selection_service_source" 2>/dev/null \
    || true
"$launch_services_register" -f "$app_destination"
"$launch_services_register" -f "$selection_service_destination"
/System/Library/CoreServices/pbs -update
"$installed_executable" --register-input-source
"$installed_executable" --enable-input-source
wait_for_status "$installed_executable" registered 1
wait_for_status "$installed_executable" enabled 1

if [[ "$was_selected" == "1" || "$was_registered" != "1" ]]; then
    "$installed_executable" --select-input-source
    wait_for_status "$installed_executable" selected 1
fi

if [[ "$(status_value "$installed_executable" selected)" == "1" ]]; then
    if ! wait_for_running_server "$installed_executable"; then
        echo "myimは入力欄へフォーカスした時点で起動します" >&2
    fi
fi

trap - EXIT
echo "インストールしました: $app_destination"
