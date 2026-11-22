# Selected text converted again with Tab
capture_reconversion() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    type_text "kanji" || return 1
    sleep 0.8
    press 48 || return 1
    sleep 0.4
    press 36 || return 1
    sleep 0.5
    press 123 shift || return 1
    press 123 shift || return 1
    sleep 0.6
    press 48 || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    [[ -n "$(editor_text)" && "$(editor_text)" != *kanji* ]]
}
