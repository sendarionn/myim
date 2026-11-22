# Japanese and English from the same romaji, without switching modes
capture_modeless() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    type_text "nihongo" || return 1
    sleep 0.9
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 0.5
    type_text "keyboard" || return 1
    sleep 0.9
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "日本語"
}
