#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
application_bundle="$repository_root/.build/myim.app"
contents_directory="$application_bundle/Contents"
executable_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
helpers_directory="$contents_directory/Helpers"
login_bundle="$helpers_directory/myim-cosense-login.app"
login_contents="$login_bundle/Contents"
login_executable_directory="$login_contents/MacOS"
iconset_directory="$repository_root/.build/myim.iconset"
ime_executable="$executable_directory/myim"
login_executable="$login_executable_directory/myim-cosense-login"

cd "$repository_root"
"$repository_root/Scripts/verify-history-date.sh"
swift build -c release --product myim-macos
swift build -c release --product myim-cosense-login

rm -rf "$application_bundle" "$iconset_directory"

mkdir -p \
    "$executable_directory" \
    "$resources_directory" \
    "$login_executable_directory"
mkdir -p "$iconset_directory"
cp ".build/release/myim-macos" "$ime_executable"
cp ".build/release/myim-cosense-login" "$login_executable"
cp "macOS/CosenseLogin-Info.plist" "$login_contents/Info.plist"

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

login_developer_rpaths=("${(@f)$(otool -l "$login_executable" | awk '
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

for developer_rpath in "${login_developer_rpaths[@]}"; do
    install_name_tool -delete_rpath "$developer_rpath" "$login_executable"
done
cp "macOS/Info.plist" "$contents_directory/Info.plist"
cp "macOS/InfoPlist.strings" "$resources_directory/InfoPlist.strings"
cp \
    "Sources/MyIMEMacOS/Resources/basic-dictionary.txt" \
    "$resources_directory/basic-dictionary.txt"
cp \
    "Sources/MyIMEMacOS/Resources/basic-dictionary-LICENSE.txt" \
    "$resources_directory/basic-dictionary-LICENSE.txt"
cp \
    "Sources/MyIMEMacOS/Resources/basic-dictionary-source.json" \
    "$resources_directory/basic-dictionary-source.json"
cp \
    "Sources/MyIMEMacOS/Resources/semantic-dictionary.jsonl" \
    "$resources_directory/semantic-dictionary.jsonl"
cp \
    "Sources/MyIMEMacOS/Resources/semantic-dictionary-source.json" \
    "$resources_directory/semantic-dictionary-source.json"
cp \
    "Sources/MyIMEMacOS/Resources/semantic-vectors.bin" \
    "$resources_directory/semantic-vectors.bin"
cp \
    "Sources/MyIMEMacOS/Resources/basic-dictionary-LICENSE.txt" \
    "$resources_directory/semantic-dictionary-LICENSE.txt"
cp \
    "Sources/MyIMEMacOS/Resources/ime-dictionary.txt" \
    "$resources_directory/ime-dictionary.txt"
cp \
    "Sources/MyIMEMacOS/Resources/ime-dictionary-source.json" \
    "$resources_directory/ime-dictionary-source.json"
cp \
    "Sources/MyIMEMacOS/Resources/ime-dictionary-LICENSE.txt" \
    "$resources_directory/ime-dictionary-LICENSE.txt"
cp \
    "Sources/MyIMEMacOS/Resources/mozc-LICENSE.txt" \
    "$resources_directory/mozc-LICENSE.txt"
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$resources_directory/myimChip.pdf" 28 36 26 white
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$iconset_directory/myim-menu-1x.pdf" 22 16 13
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$iconset_directory/myim-menu-2x.pdf" 44 32 26
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$resources_directory/app-icon.pdf" 1024 1024 640 app
sips -s format tiff -s dpiWidth 72 -s dpiHeight 72 \
    "$iconset_directory/myim-menu-1x.pdf" \
    --out "$iconset_directory/myim-menu-1x.tiff" >/dev/null
sips -m '/System/Library/ColorSync/Profiles/Generic Gray Profile.icc' \
    "$iconset_directory/myim-menu-1x.tiff" >/dev/null
sips -s format tiff -s dpiWidth 144 -s dpiHeight 144 \
    "$iconset_directory/myim-menu-2x.pdf" \
    --out "$iconset_directory/myim-menu-2x.tiff" >/dev/null
sips -m '/System/Library/ColorSync/Profiles/Generic Gray Profile.icc' \
    "$iconset_directory/myim-menu-2x.tiff" >/dev/null
tiffutil -cat \
    "$iconset_directory/myim-menu-1x.tiff" \
    "$iconset_directory/myim-menu-2x.tiff" \
    -out "$resources_directory/myimMenuTemplate.tiff"
sips -s format png -z 16 16 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$resources_directory/app-icon.pdf" \
    --out "$iconset_directory/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_directory" -o "$resources_directory/AppIcon.icns"
chmod +x "$ime_executable"
chmod +x "$login_executable"

plutil -lint "$contents_directory/Info.plist"
plutil -lint "$login_contents/Info.plist"
codesign --force --sign - "$login_bundle"
codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "macOS/myim.entitlements" \
    "$application_bundle"

echo "$application_bundle"
