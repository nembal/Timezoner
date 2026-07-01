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

resource_bundle="$(find .build -path '*release/TimeZoner_TimeZonerLib.bundle' -type d -print -quit)"
if [[ -z "$resource_bundle" ]]; then
    echo "error: TimeZoner_TimeZonerLib.bundle not found under .build" >&2
    exit 1
fi

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/
cp -R "$resource_bundle" TimeZoner.app/Contents/Resources/TimeZoner_TimeZonerLib.bundle

# Ad-hoc code sign — required for stable identity, not a substitute for notarization
codesign --force --sign - TimeZoner.app
codesign --verify TimeZoner.app

echo "Built TimeZoner.app (signed ad-hoc)"
