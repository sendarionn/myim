# Checks shared by install-macos-im.sh and diagnose-installation.sh to
# tell whether a running myim process is the installed build.
#
# A process started from the same path before the files were replaced keeps
# running the replaced executable, so the path and the launch record alone
# do not prove it is current; the executable it has loaded is compared with
# the installed file as well.

# The inode of the executable at `executable` that process `pid` has
# loaded; `path` is not used as a name since zsh ties it to PATH
myim_loaded_executable_inode() {
    local pid=$1
    local executable=$2
    local inode=""
    local line
    for line in ${(f)"$(lsof -a -p "$pid" -d txt -F in 2>/dev/null)"}; do
        case "$line" in
            i*) inode=${line#i} ;;
            n*)
                if [[ "${line#n}" == "$executable" ]]; then
                    print -r -- "$inode"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

myim_file_inode() {
    stat -f %i "$1" 2>/dev/null
}

# current: started from the installed path and running the installed file
# stale-executable: started from the installed path, running a replaced file
# foreign-path: started from somewhere else
# unknown: the loaded executable could not be read
myim_process_executable_state() {
    local pid=$1
    local expected_executable=$2
    local command_path
    local loaded_inode
    local installed_inode
    command_path=$(ps -p "$pid" -o command= 2>/dev/null)
    if [[ "$command_path" != "$expected_executable" ]]; then
        print -r -- "foreign-path"
        return 0
    fi
    loaded_inode=$(myim_loaded_executable_inode "$pid" "$expected_executable")
    installed_inode=$(myim_file_inode "$expected_executable")
    if [[ -z "$loaded_inode" || -z "$installed_inode" ]]; then
        print -r -- "unknown"
    elif [[ "$loaded_inode" == "$installed_inode" ]]; then
        print -r -- "current"
    else
        print -r -- "stale-executable"
    fi
}

# The launch record names this process and the expected build
myim_runtime_status_matches() {
    local runtime_status_file=$1
    local pid=$2
    local expected_executable=$3
    local expected_build=$4
    local expected_commit=$5
    [[ -f "$runtime_status_file" ]] || return 1
    local value key expected
    for key expected in \
        pid "$pid" \
        executable-path "$expected_executable" \
        build "$expected_build" \
        git-commit "$expected_commit"; do
        value=$(plutil -extract "$key" raw -o - "$runtime_status_file" \
            2>/dev/null)
        [[ "$value" == "$expected" ]] || return 1
    done
}

myim_running_process_ids() {
    pgrep -x myim 2>/dev/null
}

# One line per running myim process: `<pid> <state> <loaded> <installed>`
myim_describe_processes() {
    local expected_executable=$1
    local pid
    for pid in ${(f)"$(myim_running_process_ids)"}; do
        [[ -n "$pid" ]] || continue
        print -r -- "$pid $(myim_process_executable_state "$pid" "$expected_executable") $(myim_loaded_executable_inode "$pid" "$expected_executable" || print -r -- none) $(myim_file_inode "$expected_executable" || print -r -- none)"
    done
}
