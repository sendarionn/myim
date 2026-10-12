#!/bin/zsh

# Renders a README demo GIF from the conversion engine and the candidate
# panel without driving the input method, so no screen recording or
# accessibility permission is needed
#
#   ./Scripts/render-readme-demo.sh [シナリオ] [--open]

set -euo pipefail

repository_root=${0:A:h:h}
scenario=basic-conversion
open_result=0
for argument in "$@"; do
    case "$argument" in
        --open) open_result=1 ;;
        *) scenario=$argument ;;
    esac
done
output="$repository_root/.build/readme-demo-artifacts/$scenario.gif"

"$repository_root/Scripts/build-macos-ime.sh" > /dev/null
"$repository_root/.build/myim.app/Contents/MacOS/myim" \
    --render-readme-demo "$scenario" "$output"
echo "$output"
if (( open_result )); then
    open "$output"
fi
