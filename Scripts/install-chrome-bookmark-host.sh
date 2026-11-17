#!/bin/zsh
# Registers myim's bookmark host for Chrome's native messaging so the
# myim Bookmarks extension can hand this profile's bookmarks to myim.
#   ./Scripts/install-chrome-bookmark-host.sh           user location
#   ./Scripts/install-chrome-bookmark-host.sh --system  /Library location

set -euo pipefail

host_name="io.github.sendarionn.myim.bookmarks"
# Fixed by the public key in ChromeExtension/myim-bookmarks/manifest.json
extension_id="iclmdioflinlagoodmfejdbafcgdgfdm"
host_path="$HOME/Library/Input Methods/myim.app/Contents/Helpers/myim-bookmark-host"
user_directory="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
system_directory="/Library/Google/Chrome/NativeMessagingHosts"

if [[ ! -x "$host_path" ]]; then
    echo "myimのブックマーク受信プロセスがありません: $host_path" >&2
    echo "先にScripts/install-macos-im.shでmyimをインストールしてください" >&2
    exit 1
fi

manifest=$(mktemp -t myim-bookmark-host)
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<JSON
{
  "name": "$host_name",
  "description": "myim bookmark sync",
  "path": "$host_path",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$extension_id/"]
}
JSON
chmod 644 "$manifest"

if [[ "${1:-}" == "--system" ]]; then
    sudo mkdir -p "$system_directory"
    sudo cp "$manifest" "$system_directory/$host_name.json"
    echo "登録しました: $system_directory/$host_name.json"
    exit 0
fi

if mkdir -p "$user_directory" 2>/dev/null \
    && cp "$manifest" "$user_directory/$host_name.json" 2>/dev/null; then
    echo "登録しました: $user_directory/$host_name.json"
    exit 0
fi

echo "ユーザー用の登録先に書き込めません: $user_directory" >&2
echo "次のコマンドでシステム共通の登録先へ登録してください" >&2
echo "  ./Scripts/install-chrome-bookmark-host.sh --system" >&2
exit 2
