# The next input predicted after a commit. Learning starts empty, so only
# what the scenario types is suggested; the user's history comes back
# afterwards
scenario_enables=(NextInputPredictionEnabled)
scenario_changes_data=1

scenario_prepare() {
    stop_myim || return 1
    rm -f "$data_root/user/next-input-model.json" \
        "$data_root/user/candidate-selection-history.json" \
        "$data_root/user/unselected-input-learning.json" \
        "$data_root/user/generation-history.json"
}

commit_first() {
    type_text "$1" || return 1
    sleep 0.6
    press 48 || return 1
    sleep 0.3
    press 36 || return 1
    sleep 0.4
}

capture_nextinput() {
    # Learned once before recording, in a window that is then replaced by
    # an empty one
    commit_first "nihongo" || return 1
    commit_first "nyuuryoku" || return 1
    open_editor || return 1
    scenario_record "$1" 7 || return 1
    sleep 0.4
    commit_first "nihongo" || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1.4
    scenario_wait_recording || return 1
    expect_text "日本語入力"
}
