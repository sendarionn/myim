# Today's date from its reading, and a typed time in Japanese
capture_datetime() {
    scenario_record "$1" 10 || return 1
    sleep 0.4
    type_text "kyou" || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 0.3
    # The suggestions after the digits close, then a new line, so the
    # time is not read as digits after the date
    press 53 || return 1
    sleep 0.3
    press 36 || return 1
    sleep 0.4
    type_text "1330" || return 1
    sleep 1.2
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "13時30分"
}
