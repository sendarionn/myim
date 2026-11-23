#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h:h}"
cd "$repo_root"

swift run myim-macos --verify-panel-runtime
