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
system_destination="/Library/Input Methods/myim.app"
system_legacy_destination="/Library/Input Methods/my-ime.app"
runtime_status="$HOME/Library/Caches/myim/runtime-status.json"
input_session_status_directory="$HOME/Library/Caches/myim/input-sessions"
launch_services_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
rollback_required=0
had_previous_application=0
had_previous_selection_service=0
legacy_destination_cleanup_eligible=0
system_legacy_destination_cleanup_eligible=0
legacy_cleanup_reason=""

bundle_identifier() {
    local application=$1
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
        "$application/Contents/Info.plist" 2>/dev/null || true
}

bundle_executable() {
    local application=$1
    /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
        "$application/Contents/Info.plist" 2>/dev/null || true
}

build_info_value() {
    local executable=$1
    local key=$2
    "$executable" --build-info 2>/dev/null \
        | awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print }'
}

json_value() {
    local key=$1
    plutil -extract "$key" raw -o - "$runtime_status" 2>/dev/null \
        || true
}

session_json_value() {
    local file=$1
    local key=$2
    plutil -extract "$key" raw -o - "$file" 2>/dev/null || true
}

session_status_matches() {
    local file=$1
    local expected_pid=$2
    local expected_executable=$3
    local expected_build=$4
    local expected_commit=$5
    [[ "$(session_json_value "$file" pid)" == "$expected_pid" ]] \
        && [[ "$(session_json_value "$file" executable-path)" \
            == "$expected_executable" ]] \
        && [[ "$(session_json_value "$file" build)" == "$expected_build" ]] \
        && [[ "$(session_json_value "$file" git-commit)" \
            == "$expected_commit" ]] \
        && [[ -n "$(session_json_value "$file" client-bundle-id)" ]] \
        && [[ -n "$(session_json_value "$file" controller-id)" ]] \
        && [[ "$(session_json_value "$file" session-generation)" == <-> ]]
}

wait_for_current_input_session() {
    local expected_pid=$1
    local expected_executable=$2
    local expected_build=$3
    local expected_commit=$4
    local attempt
    local file
    for attempt in {1..20}; do
        for file in "$input_session_status_directory"/*.json(N); do
            if session_status_matches \
                "$file" \
                "$expected_pid" \
                "$expected_executable" \
                "$expected_build" \
                "$expected_commit"; then
                return 0
            fi
        done
        sleep 0.1
    done
    return 1
}

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
    local expected_build=$2
    local expected_commit=$3
    local attempt
    local process_id
    local myim_process_path
    local confirmed_process_id=""
    local stable_checks=0
    for attempt in {1..100}; do
        local matching_process_id=""
        local unexpected_process=""
        for process_id in ${(f)"$(pgrep -x myim 2>/dev/null || true)"}; do
            [[ -n "$process_id" ]] || continue
            myim_process_path=$(
                ps -p "$process_id" -o command= 2>/dev/null || true
            )
            if [[ "$myim_process_path" == "$expected_executable" ]]; then
                matching_process_id=$process_id
            else
                unexpected_process="$process_id:$myim_process_path"
            fi
        done
        if [[ -n "$unexpected_process" ]]; then
            echo "別の場所にあるmyimプロセスが動作しています: $unexpected_process" >&2
            return 1
        fi
        process_id=$matching_process_id
        if [[ -n "$process_id" ]] \
            && [[ -f "$runtime_status" ]] \
            && [[ "$(json_value pid)" == "$process_id" ]] \
            && [[ "$(json_value executable-path)" == "$expected_executable" ]] \
            && [[ "$(json_value build)" == "$expected_build" ]] \
            && [[ "$(json_value git-commit)" == "$expected_commit" ]]; then
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

assess_legacy_application() {
    local application=$1
    local status_executable=$2
    local process_status
    legacy_cleanup_reason=""

    if [[ ! -d "$application" ]]; then
        legacy_cleanup_reason="not-installed"
        return 1
    fi
    if [[ -L "$application" ]]; then
        legacy_cleanup_reason="symbolic-link"
        return 1
    fi
    if [[ "${application:A}" != "${legacy_destination:A}" \
        && "${application:A}" != "${system_legacy_destination:A}" ]]; then
        legacy_cleanup_reason="unexpected-path"
        return 1
    fi
    if [[ "${application:A}" == "${app_destination:A}" \
        || "${application:A}" == "${system_destination:A}" ]]; then
        legacy_cleanup_reason="current-application-path"
        return 1
    fi
    if [[ "$(bundle_identifier "$application")" \
        != "io.github.sendarionn.my-ime" ]]; then
        legacy_cleanup_reason="bundle-identifier-mismatch"
        return 1
    fi
    if [[ "$(bundle_executable "$application")" != "my-ime" ]]; then
        legacy_cleanup_reason="bundle-executable-mismatch"
        return 1
    fi
    if [[ "$(status_value "$status_executable" legacy-selected)" != "0" ]]; then
        legacy_cleanup_reason="selected-or-status-unavailable"
        return 1
    fi
    if pgrep -x my-ime >/dev/null 2>&1; then
        legacy_cleanup_reason="process-running"
        return 1
    else
        process_status=$?
        if (( process_status != 1 )); then
            legacy_cleanup_reason="process-status-unavailable"
            return 1
        fi
    fi
    return 0
}

remove_legacy_application() {
    local application=$1
    if [[ -w "${application:h}" ]]; then
        rm -rf "$application"
    else
        echo "旧名称アプリの削除に管理者権限が必要です: $application"
        /usr/bin/sudo /bin/rm -rf "$application"
    fi
}

cleanup_legacy_application() {
    local application=$1
    local status_executable=$2
    local legacy_enabled

    if ! assess_legacy_application "$application" "$status_executable"; then
        echo "LEGACY_CLEANUP=skipped:$legacy_cleanup_reason:$application"
        return 1
    fi

    legacy_enabled=$(status_value "$status_executable" legacy-enabled)
    if [[ "$legacy_enabled" == "1" ]]; then
        "$status_executable" --disable-legacy-input-source
        wait_for_status "$status_executable" legacy-enabled 0
    elif [[ "$legacy_enabled" != "0" ]]; then
        echo "LEGACY_CLEANUP=skipped:enabled-status-unavailable:$application"
        return 1
    fi

    "$launch_services_register" -u "$application"
    remove_legacy_application "$application"
    if [[ -e "$application" ]]; then
        echo "LEGACY_CLEANUP=failed:remove:$application" >&2
        return 1
    fi
    if ! wait_for_status "$status_executable" legacy-registered 0; then
        echo "LEGACY_CLEANUP=removed-registration-cache-remains:$application" >&2
        return 1
    fi
    echo "LEGACY_CLEANUP=removed:$application"
}

finish_installation() {
    local exit_code=$?
    trap - EXIT
    set +e
    cleanup_staging
    if (( exit_code != 0 && rollback_required == 1 )); then
        local rollback_failed=0
        if (( had_previous_application == 1 )); then
            restore_previous_application \
                && verify_restored_application \
                || rollback_failed=1
        else
            rm -rf "$app_destination" || rollback_failed=1
        fi
        if (( had_previous_selection_service == 1 )); then
            restore_previous_selection_service \
                && verify_restored_selection_service \
                || rollback_failed=1
        else
            rm -rf "$selection_service_destination" || rollback_failed=1
        fi
        if (( rollback_failed == 0 && had_previous_application == 1 )); then
            restore_input_source_registration || rollback_failed=1
        fi
        if (( rollback_failed == 1 )); then
            echo "旧版の復元に失敗しました" >&2
            echo "アプリのバックアップ: $previous_destination" >&2
            echo "Selection Serviceのバックアップ: $previous_selection_service" >&2
            echo "RESULT=rollback-failed" >&2
            exit 3
        fi
        echo "インストールに失敗したため置換前の状態へ戻しました" >&2
        echo "RESULT=rollback-succeeded" >&2
        rm -rf "$previous_destination" "$previous_selection_service"
    elif (( exit_code != 0 )); then
        rm -rf "$previous_destination" "$previous_selection_service"
    fi
    exit "$exit_code"
}

restore_previous_application() {
    [[ -e "$previous_destination" ]] || return 1
    mkdir -p "$app_destination"
    /usr/bin/rsync -aE --checksum --delete \
        "$previous_destination/" \
        "$app_destination/"
}

restore_previous_selection_service() {
    [[ -e "$previous_selection_service" ]] || return 1
    mkdir -p "$selection_service_destination"
    /usr/bin/rsync -aE --checksum --delete \
        "$previous_selection_service/" \
        "$selection_service_destination/"
}

verify_restored_application() {
    diff -qr "$previous_destination" "$app_destination" >/dev/null \
        && codesign --verify --deep --strict "$app_destination"
}

verify_restored_selection_service() {
    diff -qr \
        "$previous_selection_service" \
        "$selection_service_destination" >/dev/null \
        && codesign --verify \
            --deep \
            --strict \
            "$selection_service_destination"
}

restore_input_source_registration() {
    local restored_executable="$app_destination/Contents/MacOS/myim"
    "$launch_services_register" -f "$app_destination" || return 1
    if (( had_previous_selection_service == 1 )); then
        "$launch_services_register" -f "$selection_service_destination" \
            || return 1
    fi
    /System/Library/CoreServices/pbs -update || return 1
    if [[ "$was_registered" == "1" ]]; then
        "$restored_executable" --register-input-source || return 1
        "$restored_executable" --enable-input-source || return 1
    fi
    if [[ "$was_selected" == "1" ]]; then
        "$restored_executable" --select-input-source || return 1
    fi
}

if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file* ]]; then
    return 0
fi

if [[ -d "$system_destination" ]] \
    && [[ "$(bundle_identifier "$system_destination")" \
        == "io.github.sendarionn.inputmethod.myime" ]]; then
    echo "システム領域のmyimと競合するため開発版をインストールできません" >&2
    echo "競合先: $system_destination" >&2
    exit 1
fi
if [[ -d "$legacy_destination" || -d "$system_legacy_destination" ]]; then
    echo "警告: 旧名称my-ime.appが残っています" >&2
    [[ ! -d "$legacy_destination" ]] \
        || echo "  $legacy_destination" >&2
    [[ ! -d "$system_legacy_destination" ]] \
        || echo "  $system_legacy_destination" >&2
fi

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
legacy_selected=$(status_value "$source_executable" legacy-selected)

if [[ "$legacy_selected" == "1" ]]; then
    echo "旧名称my-imeが現在の入力ソースとして選択されています" >&2
    echo "別の入力ソースへ切り替えてから再実行してください" >&2
    echo "RESULT=legacy-input-source-selected" >&2
    exit 1
fi

if assess_legacy_application "$legacy_destination" "$source_executable"; then
    legacy_destination_cleanup_eligible=1
elif [[ "$legacy_cleanup_reason" != "not-installed" ]]; then
    echo "旧名称アプリを自動削除しません: $legacy_destination"
    echo "LEGACY_CLEANUP=skipped:$legacy_cleanup_reason:$legacy_destination"
fi
if assess_legacy_application \
    "$system_legacy_destination" \
    "$source_executable"; then
    system_legacy_destination_cleanup_eligible=1
elif [[ "$legacy_cleanup_reason" != "not-installed" ]]; then
    echo "旧名称アプリを自動削除しません: $system_legacy_destination"
    echo "LEGACY_CLEANUP=skipped:$legacy_cleanup_reason:$system_legacy_destination"
fi

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
trap finish_installation EXIT
ditto "$app_source" "$staged_destination"
codesign --verify --deep --strict "$staged_destination"
ditto "$selection_service_source" "$staged_selection_service"
codesign --verify --deep --strict "$staged_selection_service"

[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
[[ ! -e "$previous_selection_service" ]] || rm -rf "$previous_selection_service"
if [[ -e "$app_destination" ]]; then
    had_previous_application=1
    ditto "$app_destination" "$previous_destination"
    if ! diff -qr \
        "$app_destination" \
        "$previous_destination" >/dev/null \
        || ! codesign --verify \
            --deep \
            --strict \
            "$previous_destination"; then
        echo "myim.appのバックアップ検証に失敗しました" >&2
        exit 1
    fi
fi
if [[ -e "$selection_service_destination" ]]; then
    had_previous_selection_service=1
    ditto \
        "$selection_service_destination" \
        "$previous_selection_service"
    if ! diff -qr \
        "$selection_service_destination" \
        "$previous_selection_service" >/dev/null \
        || ! codesign --verify \
            --deep \
            --strict \
            "$previous_selection_service"; then
        echo "Selection Serviceのバックアップ検証に失敗しました" >&2
        exit 1
    fi
fi
rollback_required=1
if (( had_previous_application == 1 )); then
    /usr/bin/rsync -aE --checksum --delete \
        "$staged_destination/" \
        "$app_destination/"
else
    mkdir -p "$app_destination"
    /usr/bin/rsync -aE --checksum \
        "$staged_destination/" \
        "$app_destination/"
fi
if (( had_previous_selection_service == 1 )); then
    /usr/bin/rsync -aE --checksum --delete \
        "$staged_selection_service/" \
        "$selection_service_destination/"
else
    mkdir -p "$selection_service_destination"
    /usr/bin/rsync -aE --checksum \
        "$staged_selection_service/" \
        "$selection_service_destination/"
fi
if ! codesign --verify --deep --strict "$app_destination"; then
    echo "myim.app の検証に失敗しました" >&2
    exit 1
fi
if ! codesign --verify --deep --strict "$selection_service_destination"; then
    echo "myim-selection.service の検証に失敗しました" >&2
    exit 1
fi
cleanup_staging

installed_executable="$app_destination/Contents/MacOS/myim"
if ! diff -qr "$app_source" "$app_destination" >/dev/null; then
    echo "インストール先のmyim.appがビルド結果と一致しません" >&2
    exit 1
fi
source_selection_service_executable="$selection_service_source/Contents/MacOS/myim-selection-service"
installed_selection_service_executable="$selection_service_destination/Contents/MacOS/myim-selection-service"
if ! cmp -s \
    "$source_selection_service_executable" \
    "$installed_selection_service_executable"; then
    echo "インストール先のSelection Serviceがビルド結果と一致しません" >&2
    exit 1
fi
installed_build_number=$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
        "$app_destination/Contents/Info.plist"
)
if [[ "$installed_build_number" != "$next_build_number" ]]; then
    echo "myim.app のビルド番号が更新されていません" >&2
    exit 1
fi
installed_selection_service_build_number=$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
        "$selection_service_destination/Contents/Info.plist"
)
if [[ "$installed_selection_service_build_number" != "$next_build_number" ]]; then
    echo "myim-selection.service のビルド番号が更新されていません" >&2
    exit 1
fi
rm -f "$runtime_status"
if [[ -d "$input_session_status_directory" ]]; then
    find "$input_session_status_directory" \
        -type f \
        -name '*.json' \
        -delete
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

if (( legacy_destination_cleanup_eligible == 1 )); then
    cleanup_legacy_application \
        "$legacy_destination" \
        "$installed_executable" || true
fi
if (( system_legacy_destination_cleanup_eligible == 1 )); then
    cleanup_legacy_application \
        "$system_legacy_destination" \
        "$installed_executable" || true
fi

if [[ "$was_selected" == "1" || "$was_registered" != "1" ]]; then
    "$installed_executable" --select-input-source
    wait_for_status "$installed_executable" selected 1
fi

process_stage="not-selected"
session_stage="unverified"
running_process_id=""
if [[ "$(status_value "$installed_executable" selected)" == "1" ]]; then
    expected_commit=$(build_info_value "$installed_executable" git-commit)
    if ! wait_for_running_server \
        "$installed_executable" \
        "$installed_build_number" \
        "$expected_commit"; then
        rollback_required=0
        [[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
        [[ ! -e "$previous_selection_service" ]] || rm -rf "$previous_selection_service"
        echo "インストールは完了しましたが、新しいmyimの起動は未確認です" >&2
        echo "入力欄へフォーカスした後にScripts/diagnose-installation.shを実行してください" >&2
        echo "RESULT=installed-launch-unverified"
        exit 2
    fi
    process_stage="verified"
    running_process_id=$(json_value pid)
    if wait_for_current_input_session \
        "$running_process_id" \
        "$installed_executable" \
        "$installed_build_number" \
        "$expected_commit"; then
        session_stage="verified"
    fi
fi

rollback_required=0
[[ ! -e "$previous_destination" ]] || rm -rf "$previous_destination"
[[ ! -e "$previous_selection_service" ]] || rm -rf "$previous_selection_service"
trap - EXIT
echo "インストールしました: $app_destination"
echo "BUILD=$installed_build_number"
echo "GIT_COMMIT=$(build_info_value "$installed_executable" git-commit)"
echo "SHA256=$(shasum -a 256 "$installed_executable" | awk '{ print $1 }')"
echo "INSTALL_STAGE=verified"
echo "PROCESS_STAGE=$process_stage"
echo "SESSION_STAGE=$session_stage"
if [[ "$(status_value "$installed_executable" selected)" == "1" ]]; then
    if [[ "$session_stage" == "verified" ]]; then
        for file in "$input_session_status_directory"/*.json(N); do
            if session_status_matches \
                "$file" \
                "$running_process_id" \
                "$installed_executable" \
                "$installed_build_number" \
                "$(build_info_value "$installed_executable" git-commit)"; then
                echo "SESSION_CLIENT_BUNDLE_ID=$(session_json_value "$file" client-bundle-id)"
            fi
        done
        echo "RESULT=installed-verified"
    else
        echo "入力先アプリの新しい入力セッションは未確認です"
        echo "1. 入力ソースを一度切り替えてmyimへ戻してください"
        echo "2. 入力欄へフォーカスし直してください"
        echo "3. 未確認のままなら入力先アプリを再起動してください"
        echo "その後にScripts/diagnose-installation.sh --client-bundle-id <Bundle ID>を実行してください"
        echo "RESULT=installed-session-unverified"
    fi
else
    echo "RESULT=installed-not-selected"
fi
