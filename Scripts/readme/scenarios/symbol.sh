# Choosing a symbol shows its code point and name
capture_symbol() {
    scenario_record "$1" 7 || return 1
    sleep 0.4
    type_text "*" || return 1
    sleep 0.9
    press 48 || return 1
    sleep 0.8
    press 125 || return 1
    sleep 1.6
    press 36 || return 1
    sleep 0.8
    scenario_wait_recording || return 1
    [[ -n "$(editor_text)" && "$(editor_text)" != "*" ]]
}
