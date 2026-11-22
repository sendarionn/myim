scenario_enables=(SystemDictionaryPreviewEnabled)

# The selected candidate's meaning from the dictionaries chosen in settings
capture_dictionary() {
    scenario_record "$1" 6 || return 1
    sleep 0.4
    type_text "ringo" || return 1
    sleep 0.8
    press 48 || return 1
    sleep 3.2
    press 36 || return 1
    sleep 0.8
    scenario_wait_recording || return 1
    [[ -n "$(editor_text)" && "$(editor_text)" != *ringo* ]]
}
