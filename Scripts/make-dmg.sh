#!/bin/zsh
# 打包 DMG：./Scripts/make-dmg.sh  →  release/Mopad-<版本>.dmg
set -euo pipefail
ROOT="${0:A:h:h}"
"$ROOT/Scripts/build.sh"

APP="$ROOT/build/Mopad.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$ROOT/Resources/Info.plist")
DMG="$ROOT/release/Mopad-$VERSION.dmg"
STAGE="$(mktemp -d)/Mopad"

echo "▸ 打包 DMG…"
mkdir -p "$STAGE" "$ROOT/release"
ditto "$APP" "$STAGE/Mopad.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Mopad $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "${STAGE:h}"

(cd "${DMG:h}" && shasum -a 256 "${DMG:t}" | tee "${DMG:t}.sha256")
echo "✓ $DMG"
