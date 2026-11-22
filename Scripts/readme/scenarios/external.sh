# The external information panel, looking the candidate up on Wikipedia.
# The user's own page in external-information.js is replaced only while
# recording and put back with the rest of the data afterwards
scenario_enables=(ExternalInformationPanelEnabled)
scenario_changes_data=1

scenario_prepare() {
    local file="$data_root/extensions/external-information.js"
    [[ -f "$file" ]] || return 1
    /usr/bin/sed -i '' \
        's#^// @myim-url .*#// @myim-url https://ja.wikipedia.org/w/index.php?search=%s#' \
        "$file"
    grep -q "ja.wikipedia.org" "$file"
}

capture_external() {
    scenario_record "$1" 9 || return 1
    sleep 0.4
    type_text "ringo" || return 1
    sleep 0.8
    press 48 || return 1
    sleep 5
    press 36 || return 1
    sleep 0.8
    scenario_wait_recording || return 1
    [[ -n "$(editor_text)" && "$(editor_text)" != *ringo* ]]
}
