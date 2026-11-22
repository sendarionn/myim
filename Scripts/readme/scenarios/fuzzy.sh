# A mistyped reading still finds the word in the second panel
scenario_enables=(FuzzySuggestionsEnabled)

capture_fuzzy() {
    scenario_record "$1" 7 || return 1
    sleep 0.4
    # Typed quickly, so no partial reading lists suggestions learned
    # from the user's own input
    type_text "henknaa" 10 || return 1
    sleep 1.6
    press 48 shift || return 1
    sleep 0.8
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "変換"
}
