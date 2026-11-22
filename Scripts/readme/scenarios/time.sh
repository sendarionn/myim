# Scenario for the time input UI, sourced by Scripts/update-readme.sh.
# Types into the recording window only, and checks what was inserted before
# reporting success. The pins are dragged, so the cursor is recorded.
#
# Uses: $gui, $editor_bundle, $myim_bundle, scenario_record, editor_text

readme_section_time="時刻入力"

capture_time() {
    local movie=$1
    local expect="$editor_bundle,$myim_bundle"
    local frame x y w h
    local -a upper lower

    scenario_record "$movie" 13 cursor || return 1
    sleep 1

    # ⌥T opens the rail at the current time
    "$gui" key 17 option --expect "$editor_bundle" || return 1
    sleep 1.2

    # The upper pin moves the time; the lower pin follows until moved
    frame=$("$gui" element-frame myim "時刻のつまみ") || return 1
    read -r x y w h <<< "$frame"
    upper=($(( x + w / 2 )) $(( y + h / 2 )))
    "$gui" drag "${upper[1]}" "${upper[2]}" $(( upper[1] - 46 )) "${upper[2]}" \
        --expect "$expect" || return 1
    sleep 1

    # Moving the lower pin turns the time into a range
    frame=$("$gui" element-frame myim "終了時刻のつまみ") || return 1
    read -r x y w h <<< "$frame"
    lower=($(( x + w / 2 )) $(( y + h / 2 )))
    "$gui" drag "${lower[1]}" "${lower[2]}" $(( lower[1] + 23 )) "${lower[2]}" \
        --expect "$expect" || return 1
    sleep 1.2

    # Return lists the formats; the second one is chosen and inserted
    "$gui" key 36 --expect "$expect" || return 1
    sleep 1.5
    "$gui" key 48 --expect "$expect" || return 1
    sleep 0.6
    "$gui" key 48 --expect "$expect" || return 1
    sleep 0.8
    "$gui" key 36 --expect "$expect" || return 1
    sleep 2

    scenario_wait_recording || return 1
    # Success only when a range was actually inserted
    local text
    text=$(editor_text)
    if [[ "$text" != *"〜"* && "$text" != *" - "* && "$text" != *"から"* ]]; then
        echo "時間帯が挿入されていません: '$text'" >&2
        return 1
    fi
}
