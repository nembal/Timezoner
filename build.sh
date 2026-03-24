#!/bin/bash
set -e
cd "$(dirname "$0")"

# Apply SPM fix if needed (works around CLT PackageDescription mismatch)
if [ -x ./fix-spm.sh ]; then
    ./fix-spm.sh > /dev/null 2>&1 || true
fi
if [ -x /tmp/spm-fix/swiftc-wrapper.sh ]; then
    export SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh
fi

swift build -c release
rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/
echo "Built TimeZoner.app"
