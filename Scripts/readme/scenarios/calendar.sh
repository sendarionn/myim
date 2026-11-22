# A date chosen on the calendar, inserted in a chosen format
capture_calendar() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    press 8 option || return 1
    sleep 1.2
    press 124 || return 1
    sleep 0.4
    press 124 || return 1
    sleep 0.4
    press 125 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1.4
    press 48 || return 1
    sleep 0.5
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    [[ -n "$(editor_text)" ]]
}
