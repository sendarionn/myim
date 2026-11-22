# Selected text wrapped in a bracket chosen from the list
capture_bracket() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    type_text "mojiretsu" || return 1
    sleep 0.8
    press 48 || return 1
    sleep 0.4
    press 36 || return 1
    sleep 0.5
    press 123 shift || return 1
    press 123 shift || return 1
    press 123 shift || return 1
    sleep 0.6
    press 12 option || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1.2
    scenario_wait_recording || return 1
    expect_text "文字列"
    [[ "$(editor_text)" != "文字列" ]]
}
