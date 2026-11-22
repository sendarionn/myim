# A quantity with a unit lists it converted to related units
capture_unit() {
    scenario_record "$1" 7 || return 1
    sleep 0.4
    type_text "5km" || return 1
    sleep 1.4
    press 48 || return 1
    sleep 0.6
    press 125 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    [[ "$(editor_text)" != "5km" && -n "$(editor_text)" ]]
}
