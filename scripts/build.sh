#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/app"

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "$developer_dir" == *"/Library/Developer/CommandLineTools"* ]]; then
    bash "$ROOT/app/fix-spm.sh" >/dev/null
    export SWIFT_EXEC="/tmp/spm-fix/swiftc-wrapper.sh"
fi

swift build -c release --product TimeZoner

release_products_dir="$(swift build -c release --show-bin-path)"
resource_bundle="$release_products_dir/TimeZoner_TimeZonerLib.bundle"
executable_path="$release_products_dir/TimeZoner"
if [[ ! -d "$resource_bundle" ]]; then
    echo "error: TimeZoner_TimeZonerLib.bundle not found in $release_products_dir" >&2
    exit 1
fi
if [[ ! -x "$executable_path" ]]; then
    echo "error: TimeZoner executable not found in $release_products_dir" >&2
    exit 1
fi

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp "$executable_path" TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/
cp -R "$resource_bundle" TimeZoner.app/Contents/Resources/TimeZoner_TimeZonerLib.bundle

# Ad-hoc code sign — required for stable identity, not a substitute for notarization
codesign --force --sign - TimeZoner.app
codesign --verify TimeZoner.app

echo "Built TimeZoner.app (signed ad-hoc)"
