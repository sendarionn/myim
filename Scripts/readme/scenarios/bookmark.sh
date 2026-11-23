# Bookmarks searched with the search text typed at the caret, the found
# title's page previewed, its formats listed and left with Delete, and the
# URL inserted. Sample bookmarks stand in for the user's own while
# recording; the synced ones come back afterwards
scenario_changes_data=1
# Wide enough for the titles, the formats and the page beside them
scenario_window_rect=(120 140 1060 560)

scenario_prepare() {
    local directory="$data_root/bookmarks"
    rm -rf "$directory"
    mkdir -p "$directory" || return 1
    cat > "$directory/readme-sample.json" <<'JSON'
{
  "version": 1,
  "profileID": "readme-sample",
  "profileName": "Chrome",
  "syncedAt": "2026-01-01T00:00:00Z",
  "bookmarks": [
    {"title": "Swift", "url": "https://www.swift.org/", "folderPath": "ブックマーク バー"},
    {"title": "Swift Package Index", "url": "https://swiftpackageindex.com/", "folderPath": "ブックマーク バー / 開発"},
    {"title": "Apple Developer", "url": "https://developer.apple.com/", "folderPath": "ブックマーク バー / 開発"},
    {"title": "Wikipedia", "url": "https://ja.wikipedia.org/", "folderPath": "ブックマーク バー"}
  ]
}
JSON
}

capture_bookmark() {
    scenario_record "$1" 15 || return 1
    sleep 0.4
    press 11 option || return 1
    sleep 1.2
    type_text "swift" || return 1
    sleep 1
    press 36 || return 1
    sleep 3
    press 36 || return 1
    sleep 1.4
    press 125 || return 1
    sleep 1
    press 51 || return 1
    sleep 1.4
    press 36 || return 1
    sleep 1.2
    press 36 || return 1
    sleep 1.2
    scenario_wait_recording || return 1
    expect_text "https://www.swift.org/"
}
