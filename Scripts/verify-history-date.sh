#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
history_file="$repository_root/HISTORY.md"
today=$(TZ=Asia/Tokyo date +%F)
latest_history_date=$(
    awk '
        /^## [0-9]{4}-[0-9]{2}-[0-9]{2}$/ {
            latest = $2
        }
        END {
            print latest
        }
    ' "$history_file"
)

if [[ "$latest_history_date" != "$today" ]]; then
    echo "HISTORY.mdの最新日付が日本時間の当日ではありません" >&2
    echo "期待: $today" >&2
    echo "実際: ${latest_history_date:-なし}" >&2
    exit 1
fi

echo "HISTORY.mdの日付: $today"
