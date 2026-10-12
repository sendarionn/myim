#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
exec /usr/bin/python3 "$repository_root/Scripts/readme_demos.py" "$@"
