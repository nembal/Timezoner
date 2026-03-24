#!/bin/bash
# Fixes two known issues with Apple Command Line Tools that prevent swift build from working:
#
# 1. PackageDescription private.swiftinterface defines SwiftVersion as a separate enum,
#    while the dylib exports SwiftLanguageMode. The public swiftinterface correctly defines
#    SwiftVersion as a typealias for SwiftLanguageMode.
#
# 2. Duplicate SwiftBridging module definition in module.modulemap and bridging.modulemap.
#
# This script creates a VFS overlay at /tmp/spm-fix/ and a swiftc wrapper that applies it.
# Use: SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh swift build
# Or run this script and it will set things up.

set -e

FIX_DIR="/tmp/spm-fix"
SWIFTMODULE_DIR="/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule"
SWIFT_INCLUDE_DIR="/Library/Developer/CommandLineTools/usr/include/swift"

mkdir -p "$FIX_DIR/cache"

# Fix 1: Copy public swiftinterface as private (has correct typealias)
for arch in arm64 x86_64; do
    if [ -f "$SWIFTMODULE_DIR/${arch}-apple-macos.swiftinterface" ]; then
        cp "$SWIFTMODULE_DIR/${arch}-apple-macos.swiftinterface" \
           "$FIX_DIR/${arch}-apple-macos.private.swiftinterface"
    fi
done

# Combined VFS overlay
cat > "$FIX_DIR/vfs.yaml" << VFSEOF
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
    {
      "type": "directory",
      "name": "$SWIFTMODULE_DIR",
      "contents": [
        {
          "type": "file",
          "name": "arm64-apple-macos.private.swiftinterface",
          "external-contents": "$FIX_DIR/arm64-apple-macos.private.swiftinterface"
        },
        {
          "type": "file",
          "name": "x86_64-apple-macos.private.swiftinterface",
          "external-contents": "$FIX_DIR/x86_64-apple-macos.private.swiftinterface"
        }
      ]
    },
    {
      "type": "directory",
      "name": "$SWIFT_INCLUDE_DIR",
      "contents": [
        {
          "type": "file",
          "name": "module.modulemap",
          "external-contents": "$SWIFT_INCLUDE_DIR/bridging.modulemap"
        }
      ]
    }
  ]
}
VFSEOF

# Create wrapper
cat > "$FIX_DIR/swiftc-wrapper.sh" << 'WEOF'
#!/bin/bash
exec /Library/Developer/CommandLineTools/usr/bin/swiftc \
    -vfsoverlay /tmp/spm-fix/vfs.yaml \
    -module-cache-path /tmp/spm-fix/cache \
    "$@"
WEOF
chmod +x "$FIX_DIR/swiftc-wrapper.sh"

echo "SPM fix installed at $FIX_DIR"
echo "Use: SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh swift build"
