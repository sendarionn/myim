# A word missing from the dictionaries registered with ⌥D and then
# offered as a candidate; the user dictionary comes back afterwards
scenario_changes_data=1

capture_registration() {
    scenario_record "$1" 12 || return 1
    sleep 0.4
    type_text "maimu" || return 1
    sleep 0.8
    press 2 option || return 1
    sleep 0.8
    type_text "myim" || return 1
    sleep 0.6
    press 48 || return 1
    sleep 0.5
    # The first Return fixes what is shown, the second registers it
    press 36 || return 1
    sleep 0.8
    press 36 || return 1
    sleep 1
    type_text "maimu" || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    expect_text "myim"
}
