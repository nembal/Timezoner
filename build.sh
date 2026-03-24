#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build -c release --product TimeZoner

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/

# Ad-hoc code sign
codesign --force --sign - TimeZoner.app 2>/dev/null || true

echo "Built TimeZoner.app"
