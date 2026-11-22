# Candidates narrowed by a condition chosen with ⌥F
capture_filter() {
    scenario_record "$1" 12 || return 1
    sleep 0.4
    type_text "kami" || return 1
    sleep 1
    press 3 option || return 1
    sleep 1
    type_text "ito" || return 1
    sleep 1.2
    # 糸, then the condition that candidates contain it. The order of 糸
    # and 意図 follows what was chosen last; choosing 意図 leaves no
    # candidate, which fails the check below instead of being published
    press 48 || return 1
    sleep 0.4
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1.4
    press 48 || return 1
    sleep 0.6
    press 36 || return 1
    sleep 1
    scenario_wait_recording || return 1
    # 紙 contains 糸 as a component
    [[ -n "$(editor_text)" && "$(editor_text)" != *kami* ]]
}
