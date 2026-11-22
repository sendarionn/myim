#!/bin/zsh
# Records myim's features in a plain recording window and updates the
# images README.md shows for them. Run only when README.md is to be
# updated; normal development never runs it.
#
#   ./Scripts/update-readme.sh                 every feature with a scenario
#   ./Scripts/update-readme.sh --feature time  one feature
#   ./Scripts/update-readme.sh --list          features with a scenario
#   ./Scripts/update-readme.sh --check         README image references only
#   ./Scripts/update-readme.sh --restore       only put back data a run left
#   --skip-install                             use the installed myim
#   --keep-failed                              keep failed recordings in
#                                              .build/readme-tools to inspect
#
# The mouse and keyboard are driven while it runs; nothing should be
# touched until it finishes. Text in README.md is written by the agent
# from what the recording showed, as AGENTS.md describes.

set -u
setopt null_glob

repository_root=${0:A:h:h}
cd "$repository_root" || exit 1
scenario_directory="Scripts/readme/scenarios"
asset_directory="docs/assets"
tool_directory=".build/readme-tools"
gui="$tool_directory/gui"
stage_app="$tool_directory/myim-readme-stage.app"
editor_bundle="io.github.sendarionn.myim.readme-stage"
myim_bundle="io.github.sendarionn.inputmethod.myime"
myim_input_source="io.github.sendarionn.inputmethod.myime.Japanese"
myim_domain="$myim_bundle"
# Where the recording window is placed, in points from the top left; only
# this rectangle is recorded, with room below the text for myim's panels
window_rect=(120 140 640 420)

features=()
skip_install=0
check_only=0
keep_failed=0
restore_only=0
while (( $# > 0 )); do
    case "$1" in
        --feature) features+=("$2"); shift 2 ;;
        --skip-install) skip_install=1; shift ;;
        --keep-failed) keep_failed=1; shift ;;
        --restore) restore_only=1; shift ;;
        --check) check_only=1; shift ;;
        --list)
            for file in "$scenario_directory"/*.sh; do print -r -- "${file:t:r}"; done
            exit 0
            ;;
        *) echo "不明なオプション: $1" >&2; exit 2 ;;
    esac
done

# Local images in README.md must exist; remote ones are listed
check_readme_images() {
    local missing=0 reference
    for reference in ${(f)"$(grep -oE '!\[[^]]*\]\([^)]+\)' README.md | sed -E 's/.*\(([^)]+)\)/\1/')"}; do
        case "$reference" in
            http://*|https://*) echo "REMOTE_IMAGE=$reference" ;;
            *)
                if [[ -f "$reference" ]]; then
                    echo "LOCAL_IMAGE=$reference"
                else
                    echo "MISSING_IMAGE=$reference" >&2
                    missing=1
                fi
                ;;
        esac
    done
    return $missing
}

if (( check_only )); then
    check_readme_images
    exit $?
fi

if (( ${#features} == 0 )); then
    for file in "$scenario_directory"/*.sh; do features+=("${file:t:r}"); done
fi
for feature in "${features[@]}"; do
    [[ -f "$scenario_directory/$feature.sh" ]] || {
        echo "撮影シナリオがありません: $feature" >&2
        exit 2
    }
done

command -v ffmpeg >/dev/null || { echo "ffmpegが必要です" >&2; exit 3; }
mkdir -p "$tool_directory" "$asset_directory"
if [[ ! -x "$gui" || Scripts/readme/gui.swift -nt "$gui" ]]; then
    swiftc -O Scripts/readme/gui.swift -o "$gui" || exit 3
fi
if [[ ! -d "$stage_app" || Scripts/readme/stage.swift -nt "$stage_app/Contents/MacOS/myim-readme-stage" ]]; then
    rm -rf "$stage_app"
    mkdir -p "$stage_app/Contents/MacOS"
    swiftc -O Scripts/readme/stage.swift \
        -o "$stage_app/Contents/MacOS/myim-readme-stage" || exit 3
    # myim tells input targets apart by bundle identifier
    cat > "$stage_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$editor_bundle</string>
    <key>CFBundleName</key><string>myim README Stage</string>
    <key>CFBundleExecutable</key><string>myim-readme-stage</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST
    codesign --force --sign - "$stage_app" >/dev/null 2>&1 || exit 3
fi
"$gui" check || exit 3

if (( ! skip_install && ! restore_only )); then
    ./Scripts/install-macos-im.sh || exit 3
fi

# The user's data and settings that scenarios may change are copied aside
# before recording and put back afterwards, also after an error or an
# interruption; a copy left by a run that could not finish is put back at
# the start of the next one. Credentials are never touched
data_root="$HOME/Library/Application Support/myim"
state_root="$tool_directory/restore"
pending_state="$state_root/pending"
backup_items=(
    user bookmarks basic browser web-session
    extensions/external-information.js extensions/websearch.js
)

stop_myim() {
    pkill -x myim 2>/dev/null
    local attempt
    for attempt in {1..40}; do
        pgrep -x myim >/dev/null || return 0
        sleep 0.25
    done
    echo "myimを終了できません" >&2
    return 1
}

# Restoring stops myim, and selecting the input source does not always
# start it again, so it is started here; otherwise typing stops working
start_myim() {
    pgrep -x myim >/dev/null && return 0
    open "$HOME/Library/Input Methods/myim.app"
    local attempt
    for attempt in {1..20}; do
        pgrep -x myim >/dev/null && return 0
        sleep 0.25
    done
    echo "MYIM_NOT_STARTED=open ~/Library/Input Methods/myim.app を実行してください" >&2
    return 1
}

backup_state() {
    rm -rf "$pending_state"
    mkdir -p "$pending_state/files"
    local item
    for item in "${backup_items[@]}"; do
        if [[ -e "$data_root/$item" ]]; then
            mkdir -p "$pending_state/files/${item:h}"
            cp -a "$data_root/$item" "$pending_state/files/$item" || return 1
        else
            print -r -- "$item" >> "$pending_state/absent"
        fi
    done
    defaults export "$myim_domain" "$pending_state/defaults.plist" || return 1
    date "+%Y-%m-%d %H:%M:%S" > "$pending_state/created"
}

# Puts the copy back with myim stopped, so it cannot write its memory over
# it; what was there instead is kept beside the copy, and the copy is kept
# until the data is confirmed to match it
restore_state() {
    [[ -d "$pending_state" ]] || return 0
    stop_myim || return 1
    local stamp item source target replaced failed=0
    stamp=$(date +%Y%m%d-%H%M%S)
    replaced="$state_root/replaced-$stamp"
    for item in "${backup_items[@]}"; do
        source="$pending_state/files/$item"
        target="$data_root/$item"
        if [[ -e "$source" ]]; then
            diff -rq "$source" "$target" >/dev/null 2>&1 && continue
        elif [[ ! -e "$target" ]]; then
            continue
        fi
        if [[ -e "$target" ]]; then
            mkdir -p "$replaced/${item:h}"
            cp -a "$target" "$replaced/$item"
            rm -rf "$target"
        fi
        [[ -e "$source" ]] && cp -a "$source" "$target"
    done
    defaults import "$myim_domain" "$pending_state/defaults.plist"
    # Import only writes the saved keys; keys added while recording, such
    # as a dialog's frame, are removed
    defaults export "$myim_domain" "$work_directory/defaults-now.plist" 2>/dev/null
    local key
    for key in ${(f)"$(/usr/bin/python3 - "$pending_state/defaults.plist" "$work_directory/defaults-now.plist" <<'PYTHON'
import plistlib, sys
saved, now = (plistlib.load(open(path, "rb")) for path in sys.argv[1:3])
print("\n".join(sorted(set(now) - set(saved))))
PYTHON
)"}; do
        [[ -n "$key" ]] && defaults delete "$myim_domain" "$key"
    done
    for item in "${backup_items[@]}"; do
        source="$pending_state/files/$item"
        target="$data_root/$item"
        if [[ -e "$source" ]]; then
            diff -rq "$source" "$target" >/dev/null 2>&1 || failed=1
        else
            [[ -e "$target" ]] && failed=1
        fi
    done
    defaults export "$myim_domain" "$work_directory/defaults-now.plist" 2>/dev/null
    /usr/bin/python3 - "$pending_state/defaults.plist" "$work_directory/defaults-now.plist" <<'PYTHON' || failed=1
import plistlib, sys
saved, now = (plistlib.load(open(path, "rb")) for path in sys.argv[1:3])
sys.exit(0 if saved == now else 1)
PYTHON
    if (( failed )); then
        echo "RESTORE_FAILED=$pending_state" >&2
        return 1
    fi
    mv "$pending_state" "$state_root/restored-$stamp"
    echo "RESTORED=$(cat "$state_root/restored-$stamp/created")"
    [[ -d "$replaced" ]] && echo "REPLACED_DATA_KEPT=$replaced"
    return 0
}

work_directory=$(mktemp -d -t myim-readme)
# A copy without its completion mark was cut short before anything changed
if [[ -d "$pending_state" && ! -f "$pending_state/created" ]]; then
    rm -rf "$pending_state"
fi
if [[ -d "$pending_state" ]]; then
    echo "前回の撮影で戻せなかったデータを戻します" >&2
    restore_state || exit 3
fi
if (( restore_only )); then
    start_myim
    rm -rf "$work_directory"
    echo "RESTORE_ONLY=done"
    exit 0
fi
backup_state || { echo "データを退避できません" >&2; exit 3; }
previous_input_source=$("$gui" input-source)
recording_pid=""
# Screenshot's "Show Mouse Clicks" also circles clicks in screencapture
# recordings; it is turned off only while this runs
previous_shows_clicks=$(defaults read com.apple.screencapture showsClicks 2>/dev/null)
defaults write com.apple.screencapture showsClicks -bool false

# myim features that would show the user's own data or other pages: the
# external page, learned and next input suggestions, and panels a scenario
# does not show. They are off while recording, a scenario turns on only
# what it shows in `scenario_enables`, and every value is put back
quiet_settings=(
    ExternalInformationPanelEnabled
    FuzzySuggestionsEnabled
    NextInputPredictionEnabled
    SystemDictionaryPreviewEnabled
    AppleTranslationEnabled
)
typeset -A saved_settings saved_setting_types
for key in "${quiet_settings[@]}"; do
    saved_settings[$key]=$(defaults read "$myim_domain" "$key" 2>/dev/null || print -r -- __absent__)
    saved_setting_types[$key]=$(defaults read-type "$myim_domain" "$key" 2>/dev/null)
done

apply_scenario_settings() {
    local key
    for key in "${quiet_settings[@]}"; do
        if (( ${scenario_enables[(Ie)$key]} )); then
            defaults write "$myim_domain" "$key" -bool true
        else
            defaults write "$myim_domain" "$key" -bool false
        fi
    done
    sleep 0.5
}

restore_settings() {
    local key
    for key in "${quiet_settings[@]}"; do
        if [[ "${saved_settings[$key]}" == __absent__ ]]; then
            defaults delete "$myim_domain" "$key" 2>/dev/null
        elif [[ "${saved_setting_types[$key]}" == *boolean* ]]; then
            # Written back with the type it had
            defaults write "$myim_domain" "$key" -bool \
                "$( [[ "${saved_settings[$key]}" == 1 ]] && print true || print false )"
        else
            defaults write "$myim_domain" "$key" -int "${saved_settings[$key]}"
        fi
    done
}

cleanup() {
    [[ -n "$recording_pid" ]] && kill "$recording_pid" 2>/dev/null
    close_editor
    restore_settings
    restore_state
    start_myim
    if [[ -n "$previous_shows_clicks" ]]; then
        defaults write com.apple.screencapture showsClicks -int "$previous_shows_clicks"
    else
        defaults delete com.apple.screencapture showsClicks 2>/dev/null
    fi
    close_editor
    [[ -n "$previous_input_source" ]] \
        && "$gui" select-input-source "$previous_input_source" >/dev/null
    rm -rf "$work_directory"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# The recording window at window_rect, started empty, with myim selected
open_editor() {
    close_editor
    stage_text_file="$work_directory/stage-text"
    open -n "$stage_app" --args \
        --frame "${window_rect[@]}" --text-file "$stage_text_file" || return 1
    local attempt
    for attempt in {1..20}; do
        [[ "$("$gui" frontmost)" == "$editor_bundle" ]] && break
        sleep 0.25
    done
    [[ "$("$gui" frontmost)" == "$editor_bundle" ]] || {
        echo "撮影用ウィンドウを前面にできません" >&2
        return 1
    }
    "$gui" select-input-source "$myim_input_source" >/dev/null || return 1
    # Until macOS's input source indicator near the caret fades
    sleep 1.5
}

close_editor() {
    pkill -x myim-readme-stage 2>/dev/null
    sleep 0.3
}

editor_text() {
    cat "$stage_text_file" 2>/dev/null
}

# Records window_rect in the background for at most `seconds`; the cursor
# is shown only when the scenario passes `cursor`. Clicks are never drawn,
# since screencapture -k would circle every click
scenario_record() {
    local movie=$1 seconds=$2 cursor=${3:-}
    local -a cursor_options=()
    [[ "$cursor" == cursor ]] && cursor_options=(-C)
    screencapture -v -x "${cursor_options[@]}" -V"$seconds" \
        -R"${window_rect[1]},${window_rect[2]},${window_rect[3]},${window_rect[4]}" \
        "$movie" &
    recording_pid=$!
}

# `scenario_record_at <movie> <seconds> <cursor or ""> <x> <y> <w> <h>`
# records another rectangle, such as a settings window
scenario_record_at() {
    local movie=$1 seconds=$2 cursor=$3
    local saved=("${window_rect[@]}")
    window_rect=($4 $5 $6 $7)
    scenario_record "$movie" "$seconds" "$cursor"
    window_rect=("${saved[@]}")
}

# Center of a myim element found by its accessibility label, as "x y"
element_center() {
    local frame x y w h
    frame=$("$gui" element-frame myim "$1") || return 1
    read -r x y w h <<< "$frame"
    print -r -- "$(( x + w / 2 )) $(( y + h / 2 ))"
}

scenario_wait_recording() {
    wait "$recording_pid"
    local result=$?
    recording_pid=""
    return $result
}

# Helpers for scenarios: keys and text go only to the recording window or
# myim's panels
press() {
    "$gui" key "$@" --expect "$editor_bundle,$myim_bundle"
}

# `type_text <text> [milliseconds between keys]`
type_text() {
    "$gui" type "$1" ${2:+--delay "$2"} --expect "$editor_bundle,$myim_bundle"
}

# Fails unless the recording window holds every given text
expect_text() {
    local text needle
    text=$(editor_text)
    for needle in "$@"; do
        [[ "$text" == *"$needle"* ]] || {
            echo "「$needle」が入力されていません: '$text'" >&2
            return 1
        }
    done
}

convert_to_gif() {
    ffmpeg -loglevel error -y -i "$1" \
        -vf "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" \
        -loop 0 "$2"
}

# Replaces the image after `<!-- readme-media: feature -->` in README.md
update_readme_image() {
    local feature=$1 image=$2
    grep -q "<!-- readme-media: $feature -->" README.md || {
        echo "README_SECTION_MISSING=$feature"
        return 0
    }
    /usr/bin/python3 - "$feature" "$image" <<'PYTHON'
import re, sys
feature, image = sys.argv[1], sys.argv[2]
text = open("README.md", encoding="utf-8").read()
pattern = re.compile(
    r"(<!-- readme-media: " + re.escape(feature) + r" -->\n!\[[^\]]*\]\()[^)]+(\))"
)
updated, count = pattern.subn(lambda m: m.group(1) + image + m.group(2), text)
if count != 1:
    sys.exit("README image line after the marker not found: " + feature)
open("README.md", "w", encoding="utf-8").write(updated)
PYTHON
    echo "README_IMAGE_UPDATED=$feature"
}

# Joins recordings of the same size, leaving out what happened between them
join_movies() {
    local output=$1; shift
    local inputs=() filter="" index=0 movie
    for movie in "$@"; do
        inputs+=(-i "$movie")
        filter+="[$index:v]"
        (( index++ ))
    done
    ffmpeg -loglevel error -y "${inputs[@]}" \
        -filter_complex "${filter}concat=n=$index:v=1:a=0[v]" -map "[v]" "$output"
}

failed=()
for feature in "${features[@]}"; do
    # What a scenario file may set or define
    scenario_enables=()
    scenario_changes_data=0
    scenario_window_rect=()
    unfunction scenario_prepare 2>/dev/null
    source "$scenario_directory/$feature.sh"
    apply_scenario_settings
    movie="$work_directory/$feature.mov"
    gif="$work_directory/$feature.gif"
    # A scenario may open the recording window larger, as a plain
    # background for windows that open beside it
    default_window_rect=("${window_rect[@]}")
    (( ${#scenario_window_rect} == 4 )) && window_rect=("${scenario_window_rect[@]}")
    if (( $+functions[scenario_prepare] )) && ! scenario_prepare; then
        echo "撮影の準備ができません: $feature" >&2
        captured=0
    elif open_editor && "capture_$feature" "$movie" && convert_to_gif "$movie" "$gif"; then
        captured=1
    else
        captured=0
    fi
    window_rect=("${default_window_rect[@]}")
    if (( captured )); then
        mv "$gif" "$asset_directory/$feature.gif"
        echo "CAPTURED=$asset_directory/$feature.gif ($(du -h "$asset_directory/$feature.gif" | cut -f1))"
        update_readme_image "$feature" "$asset_directory/$feature.gif"
    else
        # The image already in README.md stays
        echo "CAPTURE_FAILED=$feature" >&2
        if (( keep_failed )) && [[ -f "$movie" ]]; then
            scenario_wait_recording 2>/dev/null
            convert_to_gif "$movie" "$tool_directory/failed-$feature.gif" \
                && echo "FAILED_RECORDING=$tool_directory/failed-$feature.gif"
        fi
        failed+=("$feature")
    fi
    [[ -n "$recording_pid" ]] && kill "$recording_pid" 2>/dev/null
    recording_pid=""
    close_editor
    # Data the scenario changed goes back before the next one records
    if (( scenario_changes_data )); then
        restore_state && backup_state || { echo "データを戻せません" >&2; exit 3; }
    fi
done

check_readme_images || failed+=("readme-images")
(( ${#failed} == 0 ))
