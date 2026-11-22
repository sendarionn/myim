# A formula ending with = lists its result
capture_calculation() {
    scenario_record "$1" 6 || return 1
    sleep 0.4
    type_text "12*34=" || return 1
    sleep 1.2
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "408"
}
