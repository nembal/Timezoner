#!/bin/bash
set -e
cd "$(dirname "$0")/../app"

swift build -c release --product TimeZoner

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/

# Ad-hoc code sign — required for stable identity, not a substitute for notarization
codesign --force --sign - TimeZoner.app

echo "Built TimeZoner.app (signed ad-hoc)"
