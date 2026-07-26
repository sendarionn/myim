#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
application_bundle="$repository_root/.build/my-ime.app"
contents_directory="$application_bundle/Contents"
executable_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
iconset_directory="$repository_root/.build/my-ime.iconset"
ime_executable="$executable_directory/my-ime"

cd "$repository_root"
swift build -c release --product my-ime-macos

mkdir -p "$executable_directory" "$resources_directory"
mkdir -p "$iconset_directory"
cp ".build/release/my-ime-macos" "$ime_executable"

developer_rpaths=("${(@f)$(otool -l "$ime_executable" | awk '
    /cmd LC_RPATH/ {
        getline
        getline
        sub(/^ *path /, "")
        sub(/ \(offset.*$/, "")
        if ($0 ~ /^\/Applications\/Xcode\.app\//) {
            print
        }
    }
')}")

for developer_rpath in "${developer_rpaths[@]}"; do
    install_name_tool -delete_rpath "$developer_rpath" "$ime_executable"
done
cp "macOS/Info.plist" "$contents_directory/Info.plist"
cp "macOS/InfoPlist.strings" "$resources_directory/InfoPlist.strings"
xcrun swift "Scripts/generate-ime-icon.swift" "$resources_directory/icon.pdf"
sips -s format png -z 16 16 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$resources_directory/icon.pdf" \
    --out "$iconset_directory/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_directory" -o "$resources_directory/AppIcon.icns"
chmod +x "$ime_executable"

plutil -lint "$contents_directory/Info.plist"
codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "macOS/my-ime.entitlements" \
    "$application_bundle"

echo "$application_bundle"
