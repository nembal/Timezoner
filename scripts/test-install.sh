#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n install.sh
bash -n scripts/build.sh
bash -n scripts/create-dmg.sh
bash -n scripts/test-install.sh
bash -n scripts/test-install-lifecycle.sh

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck install.sh scripts/build.sh scripts/create-dmg.sh scripts/test-install.sh scripts/test-install-lifecycle.sh
fi

bash scripts/test-install-lifecycle.sh

source_version="$(plutil -extract CFBundleShortVersionString raw -o - app/Info.plist)" || {
    echo "FAIL: source bundle has no release version" >&2
    exit 1
}
[[ "$source_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "FAIL: source bundle version is not a dotted numeric version" >&2
    exit 1
}
[[ "$(plutil -extract CFBundleVersion raw -o - app/Info.plist)" == "$source_version" ]] || {
    echo "FAIL: source bundle version and build value differ" >&2
    exit 1
}
wrong_version="0.0.0"
[[ "$source_version" != "$wrong_version" ]] || wrong_version="0.0.1"
if mismatch_output="$(./scripts/create-dmg.sh "$wrong_version" 2>&1)"; then
    echo "FAIL: DMG builder accepted a version that differs from source metadata" >&2
    exit 1
fi
grep -F -- "DMG version must match app/Info.plist" <<< "$mismatch_output" >/dev/null || {
    echo "FAIL: DMG builder rejected the mismatch for an unrelated reason" >&2
    exit 1
}

help_output="$(./install.sh --help)"
grep -F -- "Usage" <<<"$help_output" >/dev/null
grep -F -- "--destination" <<<"$help_output" >/dev/null
grep -F -- "--dry-run" <<<"$help_output" >/dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

dry_run_output="$(./install.sh --dry-run --destination "$tmpdir/Applications")"
grep -F -- "Would build TimeZoner.app locally" <<<"$dry_run_output" >/dev/null
grep -F -- "Would install TimeZoner.app" <<<"$dry_run_output" >/dev/null
grep -F -- "$tmpdir/Applications" <<<"$dry_run_output" >/dev/null

grep -F -- "timezoner-install-app /Applications" Formula/timezoner.rb >/dev/null
grep -F -- 'head "https://github.com/nembal/Timezoner.git", branch: "main"' Formula/timezoner.rb >/dev/null
grep -F -- '"--disable-sandbox"' Formula/timezoner.rb >/dev/null
grep -F -- "brew trust --formula nembal/timezoner/timezoner" README.md >/dev/null
grep -F -- "brew trust --formula nembal/timezoner/timezoner" scripts/dmg-readme.txt >/dev/null

bash scripts/build.sh
mkdir -p "$tmpdir/bin"
printf '#!/bin/bash\nexit 0\n' > "$tmpdir/bin/ps"
chmod +x "$tmpdir/bin/ps"
PATH="$tmpdir/bin:$PATH" ./install.sh --skip-build --destination "$tmpdir/Applications"

installed_app="$tmpdir/Applications/TimeZoner.app"
test -x "$installed_app/Contents/MacOS/TimeZoner"
test -f "$installed_app/Contents/Info.plist"
test -f "$installed_app/Contents/Resources/TimeZoner_TimeZonerLib.bundle/Contents/Resources/timezone-boundaries.json" || \
    test -f "$installed_app/Contents/Resources/TimeZoner_TimeZonerLib.bundle/timezone-boundaries.json"
codesign --verify "$installed_app"
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$installed_app/Contents/Info.plist")" == "$source_version" ]] || {
    echo "FAIL: installed app version differs from source metadata" >&2
    exit 1
}
[[ "$(plutil -extract CFBundleVersion raw -o - "$installed_app/Contents/Info.plist")" == "$source_version" ]] || {
    echo "FAIL: installed app build value differs from source metadata" >&2
    exit 1
}

echo "install.sh checks passed"
