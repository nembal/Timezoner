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

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/

# Ad-hoc code sign — required for stable identity, not a substitute for notarization
codesign --force --sign - TimeZoner.app

echo "Built TimeZoner.app (signed ad-hoc)"
