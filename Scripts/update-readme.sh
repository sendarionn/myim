#!/bin/zsh
# Records myim's features on a test TextEdit document and updates the
# images README.md shows for them. Run only when README.md is to be
# updated; normal development never runs it.
#
#   ./Scripts/update-readme.sh                 every feature with a scenario
#   ./Scripts/update-readme.sh --feature time  one feature
#   ./Scripts/update-readme.sh --list          features with a scenario
#   ./Scripts/update-readme.sh --check         README image references only
#   --skip-install                             use the installed myim
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
editor_bundle="com.apple.TextEdit"
myim_bundle="io.github.sendarionn.inputmethod.myime"
myim_input_source="io.github.sendarionn.inputmethod.myime.Japanese"
# Where the test document is placed, in points from the top left; only
# this rectangle is recorded
window_rect=(120 140 640 420)

features=()
skip_install=0
check_only=0
while (( $# > 0 )); do
    case "$1" in
        --feature) features+=("$2"); shift 2 ;;
        --skip-install) skip_install=1; shift ;;
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
"$gui" check || exit 3

if (( ! skip_install )); then
    ./Scripts/install-macos-im.sh || exit 3
fi

work_directory=$(mktemp -d -t myim-readme)
previous_input_source=$("$gui" input-source)
recording_pid=""

cleanup() {
    [[ -n "$recording_pid" ]] && kill "$recording_pid" 2>/dev/null
    close_editor
    [[ -n "$previous_input_source" ]] \
        && "$gui" select-input-source "$previous_input_source" >/dev/null
    rm -rf "$work_directory"
}
trap cleanup EXIT

# A new, empty TextEdit document at window_rect, with myim selected
open_editor() {
    osascript >/dev/null <<APPLESCRIPT || return 1
tell application "TextEdit"
    activate
    set testDocument to make new document
    set bounds of front window to {${window_rect[1]}, ${window_rect[2]}, $(( window_rect[1] + window_rect[3] )), $(( window_rect[2] + window_rect[4] ))}
end tell
APPLESCRIPT
    sleep 1
    [[ "$("$gui" frontmost)" == "$editor_bundle" ]] || {
        echo "TextEditを前面にできません" >&2
        return 1
    }
    "$gui" select-input-source "$myim_input_source" >/dev/null || return 1
    sleep 0.5
}

close_editor() {
    osascript -e 'tell application "TextEdit" to if (count of documents) > 0 then close front document saving no' \
        >/dev/null 2>&1
}

editor_text() {
    osascript -e 'tell application "TextEdit" to get text of front document'
}

# Records window_rect in the background for at most `seconds`
scenario_record() {
    local movie=$1 seconds=$2
    screencapture -v -k -x -C -V"$seconds" \
        -R"${window_rect[1]},${window_rect[2]},${window_rect[3]},${window_rect[4]}" \
        "$movie" &
    recording_pid=$!
}

scenario_wait_recording() {
    wait "$recording_pid"
    local result=$?
    recording_pid=""
    return $result
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

failed=()
for feature in "${features[@]}"; do
    source "$scenario_directory/$feature.sh"
    movie="$work_directory/$feature.mov"
    gif="$work_directory/$feature.gif"
    if open_editor && "capture_$feature" "$movie" && convert_to_gif "$movie" "$gif"; then
        mv "$gif" "$asset_directory/$feature.gif"
        echo "CAPTURED=$asset_directory/$feature.gif ($(du -h "$asset_directory/$feature.gif" | cut -f1))"
        update_readme_image "$feature" "$asset_directory/$feature.gif"
    else
        # The image already in README.md stays
        echo "CAPTURE_FAILED=$feature" >&2
        failed+=("$feature")
    fi
    [[ -n "$recording_pid" ]] && kill "$recording_pid" 2>/dev/null
    recording_pid=""
    close_editor
done

check_readme_images || failed+=("readme-images")
(( ${#failed} == 0 ))
