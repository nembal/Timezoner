#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT/app"

VERSION="${1:-0.1.0}"
APP_NAME="TimeZoner"
DMG_NAME="${APP_NAME}-${VERSION}-arm64"
RESOURCE_BUNDLE_NAME="TimeZoner_TimeZonerLib.bundle"
RESOURCE_JSON="${APP_NAME}.app/Contents/Resources/${RESOURCE_BUNDLE_NAME}/timezone-boundaries.json"

echo "Building ${APP_NAME} v${VERSION}..."

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "$developer_dir" == *"/Library/Developer/CommandLineTools"* ]]; then
    bash "$ROOT/app/fix-spm.sh" >/dev/null
    export SWIFT_EXEC="/tmp/spm-fix/swiftc-wrapper.sh"
fi

# Build release
swift build -c release --product TimeZoner

resource_bundle="$(find .build -path "*release/${RESOURCE_BUNDLE_NAME}" -type d -print -quit)"
if [[ -z "$resource_bundle" ]]; then
    echo "error: ${RESOURCE_BUNDLE_NAME} not found under .build" >&2
    exit 1
fi

# Assemble .app bundle
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp .build/release/TimeZoner "${APP_NAME}.app/Contents/MacOS/"
cp Info.plist "${APP_NAME}.app/Contents/"
cp -R "$resource_bundle" "${APP_NAME}.app/Contents/Resources/${RESOURCE_BUNDLE_NAME}"

# Add version to Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_NAME}.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_NAME}.app/Contents/Info.plist"

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
