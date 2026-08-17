#!/bin/zsh

set -euo pipefail

repository_root=${0:A:h:h}
release_directory="$repository_root/.build/release-artifacts"
payload_directory="$release_directory/payload"
component_plist="$release_directory/components.plist"
application_bundle="$repository_root/.build/myim.app"
version=${MYIM_VERSION:?MYIM_VERSIONを指定してください}
build_number=${MYIM_BUILD_NUMBER:?MYIM_BUILD_NUMBERを指定してください}
application_identity=${MYIM_CODE_SIGN_IDENTITY:?MYIM_CODE_SIGN_IDENTITYを指定してください}
installer_identity=${MYIM_INSTALLER_SIGN_IDENTITY:?MYIM_INSTALLER_SIGN_IDENTITYを指定してください}
package_path="$release_directory/myim-$version.pkg"

if [[ "$application_identity" == "-" || "$installer_identity" == "-" ]]; then
    echo "リリースにはDeveloper ID署名が必要です" >&2
    exit 1
fi

rm -rf "$release_directory"
mkdir -p "$release_directory"

MYIM_ARCHITECTURES="arm64 x86_64" \
MYIM_VERSION="$version" \
MYIM_BUILD_NUMBER="$build_number" \
MYIM_CODE_SIGN_IDENTITY="$application_identity" \
    "$repository_root/Scripts/build-macos-ime.sh"

codesign --verify --deep --strict --verbose=2 "$application_bundle"
file "$application_bundle/Contents/MacOS/myim" \
    | grep -q "arm64"
file "$application_bundle/Contents/MacOS/myim" \
    | grep -q "x86_64"
file "$application_bundle/Contents/Helpers/myim-external-browser.app/Contents/MacOS/myim-external-browser" \
    | grep -q "arm64"
file "$application_bundle/Contents/Helpers/myim-external-browser.app/Contents/MacOS/myim-external-browser" \
    | grep -q "x86_64"

mkdir -p "$payload_directory/Library/Input Methods"
COPYFILE_DISABLE=1 ditto \
    "$application_bundle" \
    "$payload_directory/Library/Input Methods/myim.app"
pkgbuild --analyze --root "$payload_directory" "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Set :0:BundleIsRelocatable false" \
    "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Set :0:BundleIsVersionChecked true" \
    "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Set :0:BundleHasStrictIdentifier true" \
    "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Set :0:BundleOverwriteAction upgrade" \
    "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Add :0:ChildBundles:0:BundleIsRelocatable bool false" \
    "$component_plist"
/usr/libexec/PlistBuddy \
    -c "Set :0:ChildBundles:0:BundleOverwriteAction upgrade" \
    "$component_plist"

pkgbuild \
    --root "$payload_directory" \
    --install-location "/" \
    --component-plist "$component_plist" \
    --scripts "$repository_root/packaging/scripts" \
    --identifier "io.github.sendarionn.myim.pkg" \
    --version "$version" \
    --ownership recommended \
    --sign "$installer_identity" \
    "$package_path"

pkgutil --check-signature "$package_path"
payload_list="$release_directory/payload-files.txt"
pkgutil --payload-files "$package_path" > "$payload_list"
if grep -q '/\._' "$payload_list"; then
    echo "PKGへAppleDoubleファイルが混入しています" >&2
    exit 1
fi
shasum -a 256 "$package_path" > "$package_path.sha256"

echo "$package_path"
