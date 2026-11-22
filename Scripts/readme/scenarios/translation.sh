# Translations of the selected candidate, chosen with the arrow keys
scenario_enables=(AppleTranslationEnabled)

capture_translation() {
    scenario_record "$1" 8 || return 1
    sleep 0.4
    type_text "ringo" || return 1
    sleep 0.8
    press 48 || return 1
    sleep 2
    press 124 || return 1
    sleep 1
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "apple"
}
