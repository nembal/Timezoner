#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n install.sh
bash -n scripts/build.sh

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck install.sh scripts/build.sh
fi

help_output="$(./install.sh --help)"
grep -F -- "Usage" <<<"$help_output" >/dev/null
grep -F -- "--destination" <<<"$help_output" >/dev/null
grep -F -- "--dry-run" <<<"$help_output" >/dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

dry_run_output="$(./install.sh --dry-run --skip-build --destination "$tmpdir/Applications")"
grep -F -- "Would install TimeZoner.app" <<<"$dry_run_output" >/dev/null
grep -F -- "$tmpdir/Applications" <<<"$dry_run_output" >/dev/null

echo "install.sh checks passed"
