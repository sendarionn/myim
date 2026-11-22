# Candidates from the bundled JavaScript extensions
capture_extensions() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    type_text "nendo" || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 0.5
    type_text "eto" || return 1
    sleep 1
    press 48 || return 1
    sleep 0.4
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "年度"
}
