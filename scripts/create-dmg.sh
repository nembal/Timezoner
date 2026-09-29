#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT/app"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/app/Info.plist")"
BUILD_VERSION="$(plutil -extract CFBundleVersion raw -o - "$ROOT/app/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || "$BUILD_VERSION" != "$VERSION" ]]; then
    echo "error: app/Info.plist must contain matching numeric version and build values" >&2
    exit 1
fi
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "$VERSION" ) ]]; then
    echo "error: DMG version must match app/Info.plist: $VERSION" >&2
    exit 64
fi
APP_NAME="TimeZoner"
DMG_NAME="${APP_NAME}-${VERSION}-arm64"
RESOURCE_BUNDLE_NAME="TimeZoner_TimeZonerLib.bundle"
RESOURCE_JSON="${APP_NAME}.app/Contents/Resources/${RESOURCE_BUNDLE_NAME}/Contents/Resources/timezone-boundaries.json"

echo "Building ${APP_NAME} v${VERSION}..."

bash "$ROOT/scripts/build.sh"

if [[ ! -f "$RESOURCE_JSON" ]]; then
    echo "error: missing resource JSON: $RESOURCE_JSON" >&2
    exit 1
fi

# Ad-hoc code sign — required for stable identity, not a substitute for notarization
codesign --force --sign - "${APP_NAME}.app"
codesign --verify "${APP_NAME}.app"

echo "Built ${APP_NAME}.app (signed ad-hoc)"

# Create DMG
rm -f "${DMG_NAME}.dmg"
DMG_DIR=$(mktemp -d)
cp -R "${APP_NAME}.app" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"
cp "$SCRIPT_DIR/dmg-readme.txt" "${DMG_DIR}/README.txt"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

rm -rf "${DMG_DIR}"

echo ""
echo "Created Manual DMG ${DMG_NAME}.dmg ($(du -h "${DMG_NAME}.dmg" | cut -f1))"
echo ""
echo "Primary install path: Homebrew source build or ./install.sh"
echo "Manual DMG fallback: open the DMG and drag TimeZoner to Applications."
