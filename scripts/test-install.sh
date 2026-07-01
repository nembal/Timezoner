#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n install.sh
bash -n scripts/build.sh
bash -n scripts/create-dmg.sh
bash -n scripts/test-install.sh

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck install.sh scripts/build.sh scripts/create-dmg.sh scripts/test-install.sh
fi

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

grep -F -- "destination=\"\${1:-\$HOME/Applications}\"" Formula/timezoner.rb >/dev/null
grep -F -- "timezoner-install-app /Applications" Formula/timezoner.rb >/dev/null
grep -F -- 'head "https://github.com/nembal/Timezoner.git", branch: "main"' Formula/timezoner.rb >/dev/null
grep -F -- '"--disable-sandbox"' Formula/timezoner.rb >/dev/null
if grep -Eq '^  url ' Formula/timezoner.rb; then
    echo "error: Formula/timezoner.rb must be HEAD-only; remove stable url" >&2
    exit 1
fi
if grep -Eq '^  sha256 ' Formula/timezoner.rb; then
    echo "error: Formula/timezoner.rb must be HEAD-only; remove stable sha256" >&2
    exit 1
fi

bash scripts/build.sh
./install.sh --skip-build --destination "$tmpdir/Applications"

installed_app="$tmpdir/Applications/TimeZoner.app"
test -x "$installed_app/Contents/MacOS/TimeZoner"
test -f "$installed_app/Contents/Info.plist"
test -f "$installed_app/Contents/Resources/TimeZoner_TimeZonerLib.bundle/timezone-boundaries.json"
codesign --verify "$installed_app"

echo "install.sh checks passed"
