#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
application_bundle="$repository_root/.build/myim.app"
contents_directory="$application_bundle/Contents"
executable_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
helpers_directory="$contents_directory/Helpers"
browser_bundle="$helpers_directory/myim-external-browser.app"
browser_contents="$browser_bundle/Contents"
browser_executable_directory="$browser_contents/MacOS"
iconset_directory="$repository_root/.build/myim.iconset"
menu_assets_directory="$repository_root/.build/myim-menu-assets"
ime_executable="$executable_directory/myim"
browser_executable="$browser_executable_directory/myim-external-browser"
extension_host="$helpers_directory/myim-extension-host"
code_sign_identity=${MYIM_CODE_SIGN_IDENTITY:--}
architectures=(${=MYIM_ARCHITECTURES:-})
version=${MYIM_VERSION:-}
build_number=${MYIM_BUILD_NUMBER:-}

cd "$repository_root"
"$repository_root/Scripts/verify-history-date.sh" --allow-existing
swift_build_arguments=(-c release --disable-sandbox)
for architecture in "${architectures[@]}"; do
    swift_build_arguments+=(--arch "$architecture")
done
swift build "${swift_build_arguments[@]}" --product myim-macos
swift build "${swift_build_arguments[@]}" --product myim-external-browser
swift build "${swift_build_arguments[@]}" --product myim-extension-host
products_directory=$(swift build "${swift_build_arguments[@]}" --show-bin-path)

rm -rf "$application_bundle" "$iconset_directory" "$menu_assets_directory"

mkdir -p \
    "$executable_directory" \
    "$resources_directory" \
    "$browser_executable_directory"
mkdir -p "$iconset_directory"
mkdir -p "$menu_assets_directory"
cp "$products_directory/myim-macos" "$ime_executable"
cp "$products_directory/myim-external-browser" "$browser_executable"
cp "$products_directory/myim-extension-host" "$extension_host"
cp "macOS/ExternalBrowser-Info.plist" "$browser_contents/Info.plist"

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
    [[ -n "$developer_rpath" ]] || continue
    install_name_tool -delete_rpath "$developer_rpath" "$ime_executable"
done

browser_developer_rpaths=("${(@f)$(otool -l "$browser_executable" | awk '
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

for developer_rpath in "${browser_developer_rpaths[@]}"; do
    [[ -n "$developer_rpath" ]] || continue
    install_name_tool -delete_rpath "$developer_rpath" "$browser_executable"
done

cp "macOS/Info.plist" "$contents_directory/Info.plist"
if [[ -n "$version" ]]; then
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleShortVersionString $version" \
        "$contents_directory/Info.plist"
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleShortVersionString $version" \
        "$browser_contents/Info.plist"
fi
if [[ -n "$build_number" ]]; then
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleVersion $build_number" \
        "$contents_directory/Info.plist"
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleVersion $build_number" \
        "$browser_contents/Info.plist"
fi
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
    "Sources/MyIMEMacOS/Resources/mozc-dictionary.txt" \
    "$resources_directory/mozc-dictionary.txt"
cp \
    "Sources/MyIMEMacOS/Resources/mozc-dictionary-source.json" \
    "$resources_directory/mozc-dictionary-source.json"
cp \
    "Sources/MyIMEMacOS/Resources/mozc-dictionary-NOTICE.txt" \
    "$resources_directory/mozc-dictionary-NOTICE.txt"
cp -R \
    "Sources/MyIMEMacOS/Resources/Extensions" \
    "$resources_directory/Extensions"
cp \
    "Sources/MyIMEMacOS/Resources/mozc-LICENSE.txt" \
    "$resources_directory/mozc-LICENSE.txt"
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$resources_directory/myimChip.pdf" 28 36 26 white
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$menu_assets_directory/myim-menu-1x.pdf" 22 16 13
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$menu_assets_directory/myim-menu-2x.pdf" 44 32 26
xcrun swift "Scripts/generate-ime-icon.swift" \
    "$resources_directory/app-icon.pdf" 1024 1024 640 app
sips -s format tiff -s dpiWidth 72 -s dpiHeight 72 \
    "$menu_assets_directory/myim-menu-1x.pdf" \
    --out "$menu_assets_directory/myim-menu-1x.tiff" >/dev/null
sips -m '/System/Library/ColorSync/Profiles/Generic Gray Profile.icc' \
    "$menu_assets_directory/myim-menu-1x.tiff" >/dev/null
sips -s format tiff -s dpiWidth 144 -s dpiHeight 144 \
    "$menu_assets_directory/myim-menu-2x.pdf" \
    --out "$menu_assets_directory/myim-menu-2x.tiff" >/dev/null
sips -m '/System/Library/ColorSync/Profiles/Generic Gray Profile.icc' \
    "$menu_assets_directory/myim-menu-2x.tiff" >/dev/null
tiffutil -cat \
    "$menu_assets_directory/myim-menu-1x.tiff" \
    "$menu_assets_directory/myim-menu-2x.tiff" \
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
chmod +x "$browser_executable"
chmod +x "$extension_host"
xattr -cr "$application_bundle"

plutil -lint "$contents_directory/Info.plist"
plutil -lint "$browser_contents/Info.plist"
if [[ "$code_sign_identity" == "-" ]]; then
    codesign --force --sign - "$extension_host"
    codesign --force --sign - "$browser_bundle"
    codesign \
        --force \
        --sign - \
        --entitlements "macOS/myim.entitlements" \
        "$application_bundle"
else
    codesign \
        --force \
        --sign "$code_sign_identity" \
        --options runtime \
        --timestamp \
        "$extension_host"
    codesign \
        --force \
        --sign "$code_sign_identity" \
        --options runtime \
        --timestamp \
        "$browser_bundle"
    codesign \
        --force \
        --sign "$code_sign_identity" \
        --options runtime \
        --timestamp \
        "$application_bundle"
fi

echo "$application_bundle"
