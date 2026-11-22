# A word missing from the dictionaries registered with ⌥D and then
# offered as a candidate; the user dictionary comes back afterwards. Each
# step waits so its result can be read in the recording
scenario_changes_data=1

capture_registration() {
    scenario_record "$1" 20 || return 1
    sleep 0.8
    # The reading, with no candidate for the word yet
    type_text "maimu" 150 || return 1
    sleep 1.8
    press 2 option || return 1
    sleep 1.6
    # What is shown and inserted for the reading
    type_text "myim" 150 || return 1
    sleep 1.4
    press 48 || return 1
    sleep 1.4
    # The first Return fixes what is shown, the second registers it
    press 36 || return 1
    sleep 1.6
    press 36 || return 1
    sleep 1.8
    # The registered word offered for the reading
    type_text "maimu" 150 || return 1
    sleep 1.8
    press 48 || return 1
    sleep 1.4
    press 36 || return 1
    sleep 2
    scenario_wait_recording || return 1
    expect_text "myim"
}
