#!/bin/zsh

set -u

repository_root=${0:A:h:h}
bundle_identifier="io.github.sendarionn.inputmethod.myime"
runtime_status="$HOME/Library/Caches/myim/runtime-status.json"
build_application="$repository_root/.build/myim.app"
build_selection_service="$repository_root/.build/myim-selection.service"
user_application="$HOME/Library/Input Methods/myim.app"
user_selection_service="$HOME/Library/Services/myim-selection.service"
system_application="/Library/Input Methods/myim.app"
problems=0
found_applications=()
install_state="diagnostic-unavailable"
run_state="diagnostic-unavailable"
history_state="missing"
legacy_state="not-installed"

sha256() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

plist_value() {
    local plist=$1
    local key=$2
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null \
        || echo unknown
}

json_value() {
    local file=$1
    local key=$2
    plutil -extract "$key" raw -o - "$file" 2>/dev/null || echo unknown
}

inspect_application() {
    local application=$1
    local plist="$application/Contents/Info.plist"
    local executable="$application/Contents/MacOS/myim"
    [[ -f "$plist" ]] || return 0
    [[ "$(plist_value "$plist" CFBundleIdentifier)" == "$bundle_identifier" ]] \
        || return 0

    found_applications+=("$application")
    echo "APPLICATION=$application"
    echo "  VERSION=$(plist_value "$plist" CFBundleShortVersionString)"
    echo "  BUILD=$(plist_value "$plist" CFBundleVersion)"
    echo "  GIT_COMMIT=$(plist_value "$plist" MyIMGitCommit)"
    echo "  GIT_DIRTY=$(plist_value "$plist" MyIMGitDirty)"
    echo "  BUILD_TIMESTAMP=$(plist_value "$plist" MyIMBuildTimestamp)"
    if [[ "$(plist_value "$plist" MyIMGitCommit)" == unknown ]]; then
        echo "  ERROR=ビルド識別情報がありません"
        problems=$((problems + 1))
    fi
    if [[ -f "$executable" ]]; then
        echo "  EXECUTABLE_SHA256=$(sha256 "$executable")"
        echo "  EXECUTABLE_MTIME=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$executable")"
    else
        echo "  ERROR=実行ファイルがありません"
        problems=$((problems + 1))
    fi
    if codesign --verify --deep --strict "$application" >/dev/null 2>&1; then
        echo "  CODE_SIGNATURE=valid"
    else
        echo "  CODE_SIGNATURE=invalid"
        problems=$((problems + 1))
    fi
}

echo "[インストール済みアプリ]"
search_roots=(
    "$HOME/Library/Input Methods"
    "/Library/Input Methods"
    "$HOME/Applications"
    "/Applications"
)
for root in "${search_roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r plist; do
        inspect_application "${plist:h:h}"
    done < <(find "$root" -maxdepth 4 -type f -path '*/Contents/Info.plist' 2>/dev/null)
done

if (( ${#found_applications[@]} == 0 )); then
    echo "APPLICATION=none"
    install_state="missing"
    problems=$((problems + 1))
elif (( ${#found_applications[@]} > 1 )); then
    echo "ERROR=同じBundle Identifierのmyimが複数あります"
    install_state="duplicate"
    problems=$((problems + 1))
fi

echo "[旧名称]"
legacy_found=0
for application in \
    "$HOME/Library/Input Methods/my-ime.app" \
    "/Library/Input Methods/my-ime.app"; do
    [[ -d "$application" ]] || continue
    legacy_found=1
    legacy_state="installed"
    legacy_plist="$application/Contents/Info.plist"
    legacy_executable_name=$(plist_value "$legacy_plist" CFBundleExecutable)
    legacy_executable="$application/Contents/MacOS/$legacy_executable_name"
    echo "LEGACY_APPLICATION=$application"
    echo "  BUNDLE_ID=$(plist_value "$legacy_plist" CFBundleIdentifier)"
    echo "  INPUT_SOURCE_ID=$(plist_value \
        "$legacy_plist" \
        'ComponentInputModeDict:tsInputModeListKey:com.apple.inputmethod.Japanese:TISInputSourceID')"
    echo "  VERSION=$(plist_value "$legacy_plist" CFBundleShortVersionString)"
    echo "  BUILD=$(plist_value "$legacy_plist" CFBundleVersion)"
    echo "  EXECUTABLE=$legacy_executable"
    if [[ -f "$legacy_executable" ]]; then
        echo "  EXECUTABLE_SHA256=$(sha256 "$legacy_executable")"
        echo "  EXECUTABLE_MTIME=$(stat \
            -f '%Sm' \
            -t '%Y-%m-%dT%H:%M:%S%z' \
            "$legacy_executable")"
    fi
    if codesign --verify --deep --strict "$application" >/dev/null 2>&1; then
        echo "  CODE_SIGNATURE=valid"
    else
        echo "  CODE_SIGNATURE=invalid"
    fi
    problems=$((problems + 1))
done
(( legacy_found == 1 )) || echo "LEGACY_APPLICATION=none"

echo "[ビルド成果物との比較]"
if [[ -f "$build_application/Contents/MacOS/myim" ]]; then
    build_sha=$(sha256 "$build_application/Contents/MacOS/myim")
    echo "BUILD_APPLICATION=$build_application"
    echo "BUILD_SHA256=$build_sha"
    file_mismatch=0
    for application in "${found_applications[@]}"; do
        executable="$application/Contents/MacOS/myim"
        [[ -f "$executable" ]] || continue
        if [[ "$(sha256 "$executable")" == "$build_sha" ]]; then
            echo "BINARY_MATCH[$application]=yes"
        else
            echo "BINARY_MATCH[$application]=no"
            file_mismatch=1
            problems=$((problems + 1))
        fi
        if diff -qr \
            "$build_application/Contents/Resources" \
            "$application/Contents/Resources" >/dev/null 2>&1; then
            echo "RESOURCES_MATCH[$application]=yes"
        else
            echo "RESOURCES_MATCH[$application]=no"
            file_mismatch=1
            problems=$((problems + 1))
        fi
        if diff -qr "$build_application" "$application" >/dev/null 2>&1; then
            echo "APP_BUNDLE_MATCH[$application]=yes"
        else
            echo "APP_BUNDLE_MATCH[$application]=no"
            file_mismatch=1
            problems=$((problems + 1))
        fi
    done
    if [[ -d "$build_selection_service" \
        && -d "$user_selection_service" ]]; then
        if diff -qr \
            "$build_selection_service" \
            "$user_selection_service" >/dev/null 2>&1; then
            echo "SELECTION_SERVICE_MATCH=yes"
        else
            echo "SELECTION_SERVICE_MATCH=no"
            file_mismatch=1
            problems=$((problems + 1))
        fi
        if codesign --verify \
            --deep \
            --strict \
            "$user_selection_service" >/dev/null 2>&1; then
            echo "SELECTION_SERVICE_SIGNATURE=valid"
        else
            echo "SELECTION_SERVICE_SIGNATURE=invalid"
            file_mismatch=1
            problems=$((problems + 1))
        fi
    else
        echo "SELECTION_SERVICE_MATCH=unknown"
        file_mismatch=1
        problems=$((problems + 1))
    fi
    if (( ${#found_applications[@]} == 1 )); then
        if (( file_mismatch == 0 )); then
            install_state="matched"
        else
            install_state="file-mismatch"
        fi
    fi
else
    echo "BUILD_APPLICATION=none"
    problems=$((problems + 1))
fi

echo "[実行中プロセス]"
main_process_count=0
process_query_failed=0
expected_running_path=""
current_process_pid=""
current_process_path=""
old_main_process=0
process_names=(
    myim
    my-ime
    myim-external-browser
    myim-extension-host
    myim-selection-service
)
for process_name in "${process_names[@]}"; do
    process_output=$(pgrep -x "$process_name" 2>/dev/null)
    process_status=$?
    if (( process_status > 1 )); then
        echo "PROCESS_NAME=$process_name"
        echo "  ERROR=プロセス一覧を取得できません"
        process_query_failed=1
        problems=$((problems + 1))
        continue
    fi
    for process_id in ${(f)process_output}; do
        [[ -n "$process_id" ]] || continue
        command_path=$(ps -p "$process_id" -o command= 2>/dev/null || true)
        echo "PROCESS_NAME=$process_name"
        echo "  PROCESS_PID=$process_id"
        echo "  PROCESS_COMMAND=$command_path"
        if [[ -z "$command_path" ]]; then
            echo "  ERROR=実行パスを取得できません"
            process_query_failed=1
            problems=$((problems + 1))
            continue
        fi
        if [[ "$process_name" == "myim" || "$process_name" == "my-ime" ]]; then
            main_process_count=$((main_process_count + 1))
            matched=false
            if [[ "$process_name" == "myim" ]]; then
                for application in "${found_applications[@]}"; do
                    if [[ "$command_path" == "$application/Contents/MacOS/myim" ]]; then
                        matched=true
                        expected_running_path="$command_path"
                        current_process_pid=$process_id
                        current_process_path=$command_path
                        break
                    fi
                done
            fi
            if [[ "$matched" != true ]]; then
                old_main_process=1
                echo "  ERROR=現行のインストール先以外の入力メソッドが動作中です"
                problems=$((problems + 1))
            fi
        fi
    done
done
if (( main_process_count == 0 )); then
    echo "PROCESS_PID=none"
    run_state="installed-not-running"
elif (( main_process_count > 1 )); then
    echo "ERROR=入力メソッドプロセスが複数動作中です"
    run_state="multiple"
    problems=$((problems + 1))
elif (( old_main_process == 1 )); then
    run_state="old-running"
else
    run_state="running-identity-unverified"
fi
if (( process_query_failed == 1 )); then
    run_state="diagnostic-unavailable"
fi

echo "[起動時ビルド情報]"
if [[ -f "$runtime_status" ]]; then
    echo "RUNTIME_STATUS=$runtime_status"
    if ! plutil -p "$runtime_status" >/dev/null 2>&1; then
        echo "  STATUS=invalid"
        history_state="invalid"
        problems=$((problems + 1))
    else
        runtime_pid=$(json_value "$runtime_status" pid)
        runtime_executable=$(json_value "$runtime_status" executable-path)
        runtime_build=$(json_value "$runtime_status" build)
        runtime_commit=$(json_value "$runtime_status" git-commit)
        echo "  PID=$runtime_pid"
        echo "  EXECUTABLE_PATH=$runtime_executable"
        echo "  VERSION=$(json_value "$runtime_status" version)"
        echo "  BUILD=$runtime_build"
        echo "  GIT_COMMIT=$runtime_commit"
        echo "  GIT_DIRTY=$(json_value "$runtime_status" git-dirty)"
        echo "  BUILD_TIMESTAMP=$(json_value "$runtime_status" build-timestamp)"
        echo "  STARTED_AT=$(json_value "$runtime_status" started-at)"

        runtime_is_current=0
        if [[ "$runtime_pid" == <-> ]] \
            && [[ "$runtime_pid" == "$current_process_pid" ]] \
            && [[ "$runtime_executable" == "$current_process_path" ]]; then
            runtime_is_current=1
        fi

        identity_matches=0
        if (( ${#found_applications[@]} == 1 )); then
            installed_application=${found_applications[1]}
            installed_plist="$installed_application/Contents/Info.plist"
            installed_executable="$installed_application/Contents/MacOS/myim"
            installed_build=$(plist_value "$installed_plist" CFBundleVersion)
            installed_commit=$(plist_value "$installed_plist" MyIMGitCommit)
            if [[ "$runtime_executable" == "$installed_executable" \
                && "$runtime_build" == "$installed_build" \
                && "$runtime_commit" == "$installed_commit" ]]; then
                identity_matches=1
                echo "  INSTALLED_IDENTITY_MATCH=yes"
            else
                echo "  ERROR=起動履歴がインストール済みアプリと一致しません"
                problems=$((problems + 1))
            fi
        fi

        if (( runtime_is_current == 1 && identity_matches == 1 )); then
            echo "  STATUS=current"
            history_state="current-matches-installed"
            if [[ "$run_state" == "running-identity-unverified" ]]; then
                run_state="running-current"
            fi
        elif (( identity_matches == 1 )); then
            echo "  STATUS=last-launch"
            history_state="last-launch-matches-installed"
        else
            echo "  STATUS=mismatch"
            history_state="mismatch"
        fi
        if [[ "$run_state" == "running-identity-unverified" ]]; then
            echo "  ERROR=実行中プロセスのビルドを確認できません"
            problems=$((problems + 1))
            run_state="diagnostic-unavailable"
        fi
    fi
else
    echo "RUNTIME_STATUS=none"
    history_state="missing"
    if (( main_process_count > 0 )); then
        echo "  ERROR=実行中プロセスのビルド情報がありません"
        problems=$((problems + 1))
        run_state="diagnostic-unavailable"
    fi
fi

echo "[入力ソース]"
status_executable=""
if [[ -n "$expected_running_path" ]]; then
    status_executable=$expected_running_path
elif [[ -x "$user_application/Contents/MacOS/myim" ]]; then
    status_executable="$user_application/Contents/MacOS/myim"
elif [[ -x "$system_application/Contents/MacOS/myim" ]]; then
    status_executable="$system_application/Contents/MacOS/myim"
fi
if [[ -n "$status_executable" ]]; then
    input_source_status=$(
        "$status_executable" --input-source-status 2>/dev/null
    )
    input_source_status_code=$?
    if (( input_source_status_code == 0 )); then
        echo "$input_source_status"
        legacy_registered=$(
            echo "$input_source_status" \
                | awk -F= '$1 == "legacy-registered" { print $2 }'
        )
        legacy_enabled=$(
            echo "$input_source_status" \
                | awk -F= '$1 == "legacy-enabled" { print $2 }'
        )
        legacy_selected=$(
            echo "$input_source_status" \
                | awk -F= '$1 == "legacy-selected" { print $2 }'
        )
        if [[ "$legacy_selected" == "1" ]]; then
            legacy_state="selected"
            problems=$((problems + 1))
        elif [[ "$legacy_enabled" == "1" ]]; then
            legacy_state="enabled"
        elif [[ "$legacy_registered" == "1" ]]; then
            legacy_state="registered"
        elif (( legacy_found == 1 )); then
            legacy_state="installed-not-registered"
        fi
    else
        echo "ERROR=入力ソース状態を取得できません"
        problems=$((problems + 1))
    fi
else
    echo "registered=unknown"
    echo "enabled=unknown"
    echo "selected=unknown"
    problems=$((problems + 1))
fi

echo "[判定]"
echo "INSTALL_STATE=$install_state"
echo "RUN_STATE=$run_state"
echo "HISTORY_STATE=$history_state"
echo "LEGACY_STATE=$legacy_state"

if (( problems == 0 )); then
    echo "RESULT=healthy"
    exit 0
fi

echo "RESULT=attention"
exit 1
