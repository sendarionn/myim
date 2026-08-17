#!/bin/zsh

set -euo pipefail

package_path=${1:?PKGのパスを指定してください}
profile=${MYIM_NOTARY_PROFILE:-myim-notary}

xcrun notarytool submit "$package_path" \
    --keychain-profile "$profile" \
    --wait
xcrun stapler staple "$package_path"
xcrun stapler validate "$package_path"
spctl --assess --type install --verbose=2 "$package_path"
pkgutil --check-signature "$package_path"
shasum -a 256 "$package_path" > "$package_path.sha256"
