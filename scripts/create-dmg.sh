#!/bin/bash
set -e
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="TimeZoner"
DMG_NAME="${APP_NAME}-${VERSION}-arm64"

echo "Building ${APP_NAME} v${VERSION}..."

# Build release
swift build -c release --product TimeZoner

# Assemble .app bundle
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp .build/release/TimeZoner "${APP_NAME}.app/Contents/MacOS/"
cp Info.plist "${APP_NAME}.app/Contents/"

# Add version to Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_NAME}.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_NAME}.app/Contents/Info.plist"

# Ad-hoc code sign
codesign --force --sign - "${APP_NAME}.app"

echo "Built ${APP_NAME}.app (signed ad-hoc)"

# Create DMG
rm -f "${DMG_NAME}.dmg"
DMG_DIR=$(mktemp -d)
cp -R "${APP_NAME}.app" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

rm -rf "${DMG_DIR}"

echo ""
echo "Created ${DMG_NAME}.dmg ($(du -h "${DMG_NAME}.dmg" | cut -f1))"
echo ""
echo "To install: Open the DMG, drag TimeZoner to Applications."
