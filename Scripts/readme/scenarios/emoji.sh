# An emoji with skin tones chosen from the recent emoji, showing its skin
# tones over the panel beside it and the platform comparison outside the
# panel at once; closed with Esc without inserting. Sample recent emoji
# stand in for the user's own, which come back afterwards
scenario_changes_data=1

scenario_prepare() {
    # The skin tone emoji are at the right of the row, so the skin tones,
    # which open to the left away from the comparison, stay in the recording
    defaults write "$myim_domain" EmojiRecentHistory -array \
        "😀" "🎉" "❤️" "✨" "👍" "👋" || return 1
    # The panel reads the recent emoji when it is made
    stop_myim
    start_myim
}

capture_emoji() {
    scenario_record "$1" 11 || return 1
    sleep 0.4
    press 14 option || return 1
    sleep 1.2
    press 125 || return 1
    sleep 0.6
    press 124 || return 1
    sleep 0.3
    press 124 || return 1
    sleep 0.3
    press 124 || return 1
    sleep 0.3
    press 124 || return 1
    sleep 1.8
    press 124 || return 1
    sleep 1.8
    press 53 || return 1
    sleep 0.8
    press 53 || return 1
    sleep 0.6
    scenario_wait_recording || return 1
    [[ -z "$(editor_text)" ]]
}
