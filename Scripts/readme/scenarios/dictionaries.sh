# A SKK dictionary imported and the basic dictionary updated from the
# settings window. The file dialog shows the user's folders, so it is left
# out of the recording; the dictionaries come back afterwards. The
# recording window opens large, so only it shows behind the settings
scenario_changes_data=1
scenario_window_rect=(0 40 1470 880)

scenario_prepare() {
    sample_dictionary="$work_directory/SKK-JISYO.sample"
    printf '%s\n' ';; okuri-nasi entries.' 'まいあいむ /myim/' > "$sample_dictionary"
}

# Waits until a myim element with the label appears
wait_for_element() {
    local attempt
    for attempt in {1..40}; do
        "$gui" element-frame myim "$1" >/dev/null 2>&1 && return 0
        sleep 0.25
    done
    return 1
}

capture_dictionaries() {
    # Opened from the input menu, near the recording window's caret; the
    # menu's own items appear a moment after it opens
    local attempt opened=0
    for attempt in 1 2 3; do
        "$gui" ax-press TextInputMenuAgent myim --menu-bar-extra || return 1
        sleep 1.5
        if "$gui" ax-press TextInputMenuAgent "myim設定" --menu-bar-extra 2>/dev/null; then
            opened=1
            break
        fi
        press 53
        sleep 0.5
    done
    (( opened )) || return 1
    wait_for_element "SKK辞書をインポート" || return 1
    sleep 1

    # The dictionary section, inside the settings window
    local settings button x y w h bx by bw bh top height
    settings=$("$gui" element-frame myim "myim設定") || return 1
    button=$("$gui" element-frame myim "表示するmacOS辞書") || return 1
    read -r x y w h <<< "$settings"
    read -r bx by bw bh <<< "$button"
    top=$(( by - 36 ))
    height=$(( y + h - top < 220 ? y + h - top : 220 ))
    local part1="$work_directory/dictionaries-1.mov"
    local part2="$work_directory/dictionaries-2.mov"
    local -a point

    scenario_record_at "$part1" 3 cursor $(( x + 1 )) "$top" $(( w - 2 )) "$height" || return 1
    sleep 1
    point=($(element_center "SKK辞書をインポート")) || return 1
    "$gui" click "${point[@]}" --expect "$editor_bundle,$myim_bundle" || return 1
    scenario_wait_recording || return 1

    # The file dialog, typed in ASCII, unrecorded
    sleep 1.5
    "$gui" select-input-source com.apple.keylayout.ABC >/dev/null \
        || "$gui" select-input-source com.apple.keylayout.US >/dev/null
    press 5 command shift || return 1
    sleep 1
    type_text "$sample_dictionary" 20 || return 1
    sleep 1
    press 36 || return 1
    sleep 1.5
    press 36 || return 1
    # The alert reporting the import, then the new dictionary in the list
    wait_for_element "SKK辞書をインポートしました" || return 1
    sleep 0.5
    press 36 || return 1
    wait_for_element "SKK-JISYO.sample" || return 1
    "$gui" select-input-source "$myim_input_source" >/dev/null
    sleep 0.5
    # The new dictionary is below the visible part of the window
    "$gui" scroll $(( x + w / 2 )) $(( y + h / 2 )) -20 \
        --expect "$editor_bundle,$myim_bundle" || return 1
    sleep 1
    local sx sy sw sh bottom
    read -r sx sy sw sh <<< "$("$gui" element-frame myim "SKK-JISYO.sample")"
    bottom=$(( sy + sh + 10 < y + h ? sy + sh + 10 : y + h ))

    scenario_record_at "$part2" 4 cursor $(( x + 1 )) $(( bottom - height )) $(( w - 2 )) "$height" || return 1
    sleep 1.4
    point=($(element_center "TKGJE基本辞書を更新")) || return 1
    "$gui" click "${point[@]}" --expect "$editor_bundle,$myim_bundle" || return 1
    scenario_wait_recording || return 1

    join_movies "$1" "$part1" "$part2"
}
