# Emoji chosen with the arrow keys and compared across platforms; closed
# with Esc without inserting, which would change the recent emoji
capture_emoji() {
    scenario_record "$1" 8 || return 1
    sleep 0.4
    press 14 option || return 1
    sleep 1
    press 125 || return 1
    sleep 0.8
    press 124 || return 1
    sleep 1.2
    press 124 || return 1
    sleep 1.4
    press 53 || return 1
    sleep 0.8
    scenario_wait_recording || return 1
    [[ -z "$(editor_text)" ]]
}
