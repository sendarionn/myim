#!/bin/zsh

set -u

repository_root=${0:A:h:h}
bundle_identifier="io.github.sendarionn.inputmethod.myime"
runtime_status="$HOME/Library/Caches/myim/runtime-status.json"
build_application="$repository_root/.build/myim.app"
user_application="$HOME/Library/Input Methods/myim.app"
system_application="/Library/Input Methods/myim.app"
problems=0
found_applications=()

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
    problems=$((problems + 1))
elif (( ${#found_applications[@]} > 1 )); then
    echo "ERROR=同じBundle Identifierのmyimが複数あります"
    problems=$((problems + 1))
fi

echo "[旧名称]"
legacy_found=0
for application in \
    "$HOME/Library/Input Methods/my-ime.app" \
    "/Library/Input Methods/my-ime.app"; do
    [[ -d "$application" ]] || continue
    legacy_found=1
    echo "LEGACY_APPLICATION=$application"
    echo "  BUNDLE_ID=$(plist_value "$application/Contents/Info.plist" CFBundleIdentifier)"
    echo "  BUILD=$(plist_value "$application/Contents/Info.plist" CFBundleVersion)"
    problems=$((problems + 1))
done
(( legacy_found == 1 )) || echo "LEGACY_APPLICATION=none"

echo "[ビルド成果物との比較]"
if [[ -f "$build_application/Contents/MacOS/myim" ]]; then
    build_sha=$(sha256 "$build_application/Contents/MacOS/myim")
    echo "BUILD_APPLICATION=$build_application"
    echo "BUILD_SHA256=$build_sha"
    for application in "${found_applications[@]}"; do
        executable="$application/Contents/MacOS/myim"
        [[ -f "$executable" ]] || continue
        if [[ "$(sha256 "$executable")" == "$build_sha" ]]; then
            echo "BINARY_MATCH[$application]=yes"
        else
            echo "BINARY_MATCH[$application]=no"
            problems=$((problems + 1))
        fi
        if diff -qr \
            "$build_application/Contents/Resources" \
            "$application/Contents/Resources" >/dev/null 2>&1; then
            echo "RESOURCES_MATCH[$application]=yes"
        else
            echo "RESOURCES_MATCH[$application]=no"
            problems=$((problems + 1))
        fi
    done
else
    echo "BUILD_APPLICATION=none"
    problems=$((problems + 1))
fi

echo "[実行中プロセス]"
running_count=0
expected_running_path=""
for process_id in ${(f)"$(pgrep -x myim 2>/dev/null || true)"}; do
    [[ -n "$process_id" ]] || continue
    running_count=$((running_count + 1))
    command_path=$(ps -p "$process_id" -o command= 2>/dev/null || true)
    echo "PROCESS_PID=$process_id"
    echo "  PROCESS_COMMAND=$command_path"
    matched=false
    for application in "${found_applications[@]}"; do
        if [[ "$command_path" == "$application/Contents/MacOS/myim" ]]; then
            matched=true
            expected_running_path="$command_path"
            break
        fi
    done
    if [[ "$matched" != true ]]; then
        echo "  ERROR=登録済みアプリ以外のmyimが動作中です"
        problems=$((problems + 1))
    fi
done
(( running_count > 0 )) || echo "PROCESS_PID=none"
if (( running_count > 1 )); then
    echo "ERROR=myimプロセスが複数動作中です"
    problems=$((problems + 1))
fi

echo "[起動時ビルド情報]"
if [[ -f "$runtime_status" ]]; then
    runtime_pid=$(json_value "$runtime_status" pid)
    runtime_executable=$(json_value "$runtime_status" executable-path)
    runtime_build=$(json_value "$runtime_status" build)
    runtime_commit=$(json_value "$runtime_status" git-commit)
    echo "RUNTIME_STATUS=$runtime_status"
    echo "  PID=$runtime_pid"
    echo "  EXECUTABLE_PATH=$runtime_executable"
    echo "  VERSION=$(json_value "$runtime_status" version)"
    echo "  BUILD=$runtime_build"
    echo "  GIT_COMMIT=$runtime_commit"
    echo "  GIT_DIRTY=$(json_value "$runtime_status" git-dirty)"
    echo "  BUILD_TIMESTAMP=$(json_value "$runtime_status" build-timestamp)"
    echo "  STARTED_AT=$(json_value "$runtime_status" started-at)"
    if [[ "$runtime_pid" != <-> ]] \
        || ! kill -0 "$runtime_pid" 2>/dev/null; then
        echo "  STATUS=stale"
    elif [[ -n "$expected_running_path" ]] \
        && [[ "$(json_value "$runtime_status" executable-path)" \
            != "$expected_running_path" ]]; then
        echo "  STATUS=path-mismatch"
        problems=$((problems + 1))
    else
        echo "  STATUS=running"
    fi
    if (( ${#found_applications[@]} == 1 )); then
        installed_application=${found_applications[1]}
        installed_plist="$installed_application/Contents/Info.plist"
        installed_executable="$installed_application/Contents/MacOS/myim"
        installed_build=$(plist_value "$installed_plist" CFBundleVersion)
        installed_commit=$(plist_value "$installed_plist" MyIMGitCommit)
        if [[ "$runtime_executable" != "$installed_executable" \
            || "$runtime_build" != "$installed_build" \
            || "$runtime_commit" != "$installed_commit" ]]; then
            echo "  ERROR=起動時ビルド情報がインストール済みアプリと一致しません"
            problems=$((problems + 1))
        else
            echo "  INSTALLED_IDENTITY_MATCH=yes"
        fi
    fi
else
    echo "RUNTIME_STATUS=none"
    if (( running_count > 0 )); then
        echo "  ERROR=実行中プロセスのビルド情報がありません"
        problems=$((problems + 1))
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
    if ! "$status_executable" --input-source-status 2>/dev/null; then
        echo "ERROR=入力ソース状態を取得できません"
        problems=$((problems + 1))
    fi
else
    echo "registered=unknown"
    echo "enabled=unknown"
    echo "selected=unknown"
    problems=$((problems + 1))
fi

if (( problems == 0 )); then
    echo "RESULT=healthy"
    exit 0
fi

echo "RESULT=attention"
exit 1
