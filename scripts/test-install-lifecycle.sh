#!/bin/bash
# shellcheck disable=SC2016 # Fixture scripts intentionally expand variables when executed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

make_source_bundle() {
    local root="$1"
    local bundle="$root/app/TimeZoner.app"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/TimeZoner_TimeZonerLib.bundle"
    printf 'new binary\n' > "$bundle/Contents/MacOS/TimeZoner"
    chmod +x "$bundle/Contents/MacOS/TimeZoner"
    printf 'plist\n' > "$bundle/Contents/Info.plist"
    printf '{}\n' > "$bundle/Contents/Resources/TimeZoner_TimeZonerLib.bundle/timezone-boundaries.json"
    cp "$repo_root/install.sh" "$root/install.sh"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_formula_helper() {
    ruby - "$repo_root/Formula/timezoner.rb" "$1" "$2" <<'RUBY'
source = File.read(ARGV[0])
body = source[/^    \(bin\/"timezoner-install-app"\)\.write <<~EOS\n(.*?)^    EOS$/m, 1]
abort "Homebrew install helper missing" unless body
prefix = ARGV[1]
script = eval("<<~EOS\n#{body}    EOS\n", binding, ARGV[0])
File.write(ARGV[2], script)
RUBY
    chmod +x "$2"
}

case "${1:-all}" in
    equal|all)
        equal_root="$test_root/equal"
        make_source_bundle "$equal_root"
        mkdir -p "$equal_root/bin"
        printf '#!/bin/bash\nexit 0\n' > "$equal_root/bin/codesign"
        chmod +x "$equal_root/bin/codesign"

        if PATH="$equal_root/bin:$PATH" "$equal_root/install.sh" --skip-build \
            --destination "$equal_root/app/../app" > "$equal_root/output" 2>&1; then
            fail "install accepted the source bundle as its destination"
        fi
        test -x "$equal_root/app/TimeZoner.app/Contents/MacOS/TimeZoner" || \
            fail "equal source and destination destroyed the source bundle"
        grep -qi 'source.*destination\|destination.*source' "$equal_root/output" || \
            fail "equal source and destination did not explain the rejection"
        ;;
    open|formula|formula-open|crosspath|formula-crosspath)
        ;;
    *)
        fail "unknown case: $1"
        ;;
esac

if [[ "${1:-all}" == "equal" || "${1:-all}" == "all" ]]; then
    missing_root="$test_root/missing-component"
    make_source_bundle "$missing_root"
    mkdir -p "$missing_root/bin"
    printf '#!/bin/bash\nexit 0\n' > "$missing_root/bin/codesign"
    chmod +x "$missing_root/bin/codesign"
    if PATH="$missing_root/bin:$PATH" "$missing_root/install.sh" --skip-build \
        --destination "$missing_root/app/new-segment/.." > "$missing_root/output" 2>&1; then
        fail "install accepted a missing-component alias to its source bundle"
    fi
    test -x "$missing_root/app/TimeZoner.app/Contents/MacOS/TimeZoner" || \
        fail "missing-component destination alias destroyed the source bundle"
    grep -qi 'source.*destination\|destination.*source' "$missing_root/output" || \
        fail "missing-component destination alias did not explain rejection"
fi

if [[ "${1:-all}" == "open" || "${1:-all}" == "all" ]]; then
    open_root="$test_root/open"
    make_source_bundle "$open_root"
    mkdir -p "$open_root/Applications/TimeZoner.app/Contents/MacOS" "$open_root/bin"
    printf 'old binary\n' > "$open_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$open_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    TZ_TEST_DESTINATION="$(cd -P "$open_root/Applications" && pwd -P)/TimeZoner.app"
    export TZ_TEST_DESTINATION
    export TZ_TEST_OPEN_DESTINATION="$open_root/Applications/TimeZoner.app"
    export TZ_TEST_KILLED="$open_root/killed"
    export TZ_TEST_OPENED="$open_root/opened"

    printf '#!/bin/bash\nexit 0\n' > "$open_root/bin/codesign"
    printf '%s\n' '#!/bin/bash' \
        'printf "52525 /Applications/Unrelated.app/Contents/MacOS/Unrelated\n"' \
        'if [[ ! -f "$TZ_TEST_KILLED" ]]; then' \
        '  printf "42424 %s/Contents/MacOS/TimeZoner\n" "$TZ_TEST_OPEN_DESTINATION"' \
        'fi' > "$open_root/bin/ps"
    printf '%s\n' '#!/bin/bash' \
        '[[ "$1" == "$TZ_TEST_OPEN_DESTINATION" ]] || exit 1' \
        '[[ -f "$TZ_TEST_KILLED" ]] || exit 1' \
        '[[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "new binary" ]] || exit 1' \
        'touch "$TZ_TEST_OPENED"' > "$open_root/bin/open"
    printf '%s\n' 'kill() {' \
        '  [[ "$1" == "-TERM" && "$2" == "42424" ]] || return 1' \
        '  [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "old binary" ]] || return 1' \
        '  touch "$TZ_TEST_KILLED"' \
        '}' > "$open_root/bash-env"
    chmod +x "$open_root/bin/"*

    PATH="$open_root/bin:$PATH" BASH_ENV="$open_root/bash-env" \
        "$open_root/install.sh" --skip-build --destination "$open_root/Applications" --open \
        > "$open_root/output" 2>&1 || {
            sed -n '1,120p' "$open_root/output" >&2
            fail "update-open did not stop, replace, and launch the installed bundle"
        }
    test -f "$TZ_TEST_KILLED" || fail "prior installed process was not stopped"
    test -f "$TZ_TEST_OPENED" || fail "installed bundle was not launched"
fi

if [[ "${1:-all}" == "formula" || "${1:-all}" == "all" ]]; then
    formula_root="$test_root/formula"
    make_source_bundle "$formula_root"
    mkdir -p "$formula_root/prefix" "$formula_root/bin"
    cp -R "$formula_root/app/TimeZoner.app" "$formula_root/prefix/TimeZoner.app"
    write_formula_helper "$formula_root/prefix" "$formula_root/timezoner-install-app"
    printf '#!/bin/bash\nexit 0\n' > "$formula_root/bin/codesign"
    chmod +x "$formula_root/bin/codesign"
    if PATH="$formula_root/bin:$PATH" "$formula_root/timezoner-install-app" \
        "$formula_root/prefix" > "$formula_root/equal-output" 2>&1; then
        fail "Homebrew install helper accepted its source bundle as destination"
    fi
    test -x "$formula_root/prefix/TimeZoner.app/Contents/MacOS/TimeZoner" || \
        fail "Homebrew equal source and destination destroyed the source bundle"
    grep -qi 'source.*destination\|destination.*source' "$formula_root/equal-output" || \
        fail "Homebrew equal source and destination did not explain rejection"

    missing_formula_root="$test_root/formula-missing-component"
    make_source_bundle "$missing_formula_root"
    mkdir -p "$missing_formula_root/prefix" "$missing_formula_root/bin"
    cp -R "$missing_formula_root/app/TimeZoner.app" "$missing_formula_root/prefix/TimeZoner.app"
    write_formula_helper "$missing_formula_root/prefix" "$missing_formula_root/timezoner-install-app"
    printf '#!/bin/bash\nexit 0\n' > "$missing_formula_root/bin/codesign"
    chmod +x "$missing_formula_root/bin/codesign"
    if PATH="$missing_formula_root/bin:$PATH" "$missing_formula_root/timezoner-install-app" \
        "$missing_formula_root/prefix/new-segment/.." > "$missing_formula_root/output" 2>&1; then
        fail "Homebrew helper accepted a missing-component alias to its source bundle"
    fi
    test -x "$missing_formula_root/prefix/TimeZoner.app/Contents/MacOS/TimeZoner" || \
        fail "Homebrew missing-component alias destroyed the source bundle"
    grep -qi 'source.*destination\|destination.*source' "$missing_formula_root/output" || \
        fail "Homebrew missing-component alias did not explain rejection"
fi

if [[ "${1:-all}" == "crosspath" || "${1:-all}" == "all" ]]; then
    conflict_root="$test_root/crosspath"
    make_source_bundle "$conflict_root"
    mkdir -p "$conflict_root/Applications/TimeZoner.app/Contents/MacOS" \
        "$conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS" "$conflict_root/bin"
    printf 'old binary\n' > "$conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    printf 'other binary\n' > "$conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    cp "$repo_root/app/Info.plist" "$conflict_root/OtherApplications/OldTimeZoner.app/Contents/Info.plist"
    TZ_TEST_OTHER_EXECUTABLE="$(cd -P "$conflict_root/OtherApplications" && pwd -P)/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    export TZ_TEST_OTHER_EXECUTABLE
    export TZ_TEST_OPENED="$conflict_root/opened"
    export TZ_TEST_KILLED="$conflict_root/killed"
    printf '#!/bin/bash\nexit 0\n' > "$conflict_root/bin/codesign"
    printf '%s\n' '#!/bin/bash' \
        'printf "52525 %s\n" "$TZ_TEST_OTHER_EXECUTABLE"' > "$conflict_root/bin/ps"
    printf '%s\n' '#!/bin/bash' 'touch "$TZ_TEST_OPENED"' > "$conflict_root/bin/open"
    printf '%s\n' 'kill() { touch "$TZ_TEST_KILLED"; }' > "$conflict_root/bash-env"
    chmod +x "$conflict_root/bin/"*
    if PATH="$conflict_root/bin:$PATH" BASH_ENV="$conflict_root/bash-env" \
        "$conflict_root/install.sh" --skip-build --destination "$conflict_root/Applications" --open \
        > "$conflict_root/output" 2>&1; then
        fail "update-open claimed success while another TimeZoner copy was running"
    fi
    [[ "$(< "$conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
        fail "cross-path conflict replaced the installed bundle before reporting failure"
    test ! -f "$TZ_TEST_KILLED" || fail "cross-path conflict stopped the other TimeZoner process"
    test ! -f "$TZ_TEST_OPENED" || fail "cross-path conflict opened a new bundle"
    grep -F -- "$TZ_TEST_OTHER_EXECUTABLE" "$conflict_root/output" >/dev/null || \
        fail "cross-path conflict did not identify the running copy"
fi

if [[ "${1:-all}" == "formula-crosspath" || "${1:-all}" == "all" ]]; then
    formula_conflict_root="$test_root/formula-crosspath"
    make_source_bundle "$formula_conflict_root"
    mkdir -p "$formula_conflict_root/prefix" \
        "$formula_conflict_root/Applications/TimeZoner.app/Contents/MacOS" \
        "$formula_conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS" \
        "$formula_conflict_root/bin"
    cp -R "$formula_conflict_root/app/TimeZoner.app" "$formula_conflict_root/prefix/TimeZoner.app"
    write_formula_helper "$formula_conflict_root/prefix" "$formula_conflict_root/timezoner-install-app"
    printf 'old binary\n' > "$formula_conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$formula_conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    printf 'other binary\n' > "$formula_conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$formula_conflict_root/OtherApplications/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    cp "$repo_root/app/Info.plist" "$formula_conflict_root/OtherApplications/OldTimeZoner.app/Contents/Info.plist"
    TZ_TEST_OTHER_EXECUTABLE="$(cd -P "$formula_conflict_root/OtherApplications" && pwd -P)/OldTimeZoner.app/Contents/MacOS/TimeZoner"
    export TZ_TEST_OTHER_EXECUTABLE
    export TZ_TEST_OPENED="$formula_conflict_root/opened"
    export TZ_TEST_KILLED="$formula_conflict_root/killed"
    printf '#!/bin/bash\nexit 0\n' > "$formula_conflict_root/bin/codesign"
    printf '%s\n' '#!/bin/bash' \
        'printf "52525 %s\n" "$TZ_TEST_OTHER_EXECUTABLE"' > "$formula_conflict_root/bin/ps"
    printf '%s\n' '#!/bin/bash' 'touch "$TZ_TEST_OPENED"' > "$formula_conflict_root/bin/open"
    printf '%s\n' 'kill() { touch "$TZ_TEST_KILLED"; }' > "$formula_conflict_root/bash-env"
    chmod +x "$formula_conflict_root/bin/"*
    if PATH="$formula_conflict_root/bin:$PATH" BASH_ENV="$formula_conflict_root/bash-env" \
        "$formula_conflict_root/timezoner-install-app" "$formula_conflict_root/Applications" --open \
        > "$formula_conflict_root/output" 2>&1; then
        fail "Homebrew update-open claimed success while another TimeZoner copy was running"
    fi
    [[ "$(< "$formula_conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
        fail "Homebrew cross-path conflict replaced the installed bundle before reporting failure"
    test ! -f "$TZ_TEST_KILLED" || fail "Homebrew cross-path conflict stopped the other TimeZoner process"
    test ! -f "$TZ_TEST_OPENED" || fail "Homebrew cross-path conflict opened a new bundle"
    grep -F -- "$TZ_TEST_OTHER_EXECUTABLE" "$formula_conflict_root/output" >/dev/null || \
        fail "Homebrew cross-path conflict did not identify the running copy"
fi

if [[ "${1:-all}" == "formula-open" || "${1:-all}" == "all" ]]; then
    formula_open_root="$test_root/formula-open"
    make_source_bundle "$formula_open_root"
    mkdir -p "$formula_open_root/prefix" "$formula_open_root/Applications/TimeZoner.app/Contents/MacOS" "$formula_open_root/bin"
    cp -R "$formula_open_root/app/TimeZoner.app" "$formula_open_root/prefix/TimeZoner.app"
    printf 'old binary\n' > "$formula_open_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    chmod +x "$formula_open_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
    write_formula_helper "$formula_open_root/prefix" "$formula_open_root/timezoner-install-app"
    TZ_TEST_DESTINATION="$(cd -P "$formula_open_root/Applications" && pwd -P)/TimeZoner.app"
    export TZ_TEST_DESTINATION
    export TZ_TEST_OPEN_DESTINATION="$formula_open_root/Applications/TimeZoner.app"
    export TZ_TEST_KILLED="$formula_open_root/killed"
    export TZ_TEST_OPENED="$formula_open_root/opened"

    printf '#!/bin/bash\nexit 0\n' > "$formula_open_root/bin/codesign"
    printf '%s\n' '#!/bin/bash' \
        'printf "52525 /Applications/Unrelated.app/Contents/MacOS/Unrelated\n"' \
        'if [[ ! -f "$TZ_TEST_KILLED" ]]; then' \
        '  printf "42424 %s/Contents/MacOS/TimeZoner\n" "$TZ_TEST_OPEN_DESTINATION"' \
        'fi' > "$formula_open_root/bin/ps"
    printf '%s\n' '#!/bin/bash' \
        '[[ "$1" == "$TZ_TEST_OPEN_DESTINATION" ]] || exit 1' \
        '[[ -f "$TZ_TEST_KILLED" ]] || exit 1' \
        '[[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "new binary" ]] || exit 1' \
        'touch "$TZ_TEST_OPENED"' > "$formula_open_root/bin/open"
    printf '%s\n' 'kill() {' \
        '  [[ "$1" == "-TERM" && "$2" == "42424" ]] || return 1' \
        '  [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "old binary" ]] || return 1' \
        '  touch "$TZ_TEST_KILLED"' \
        '}' > "$formula_open_root/bash-env"
    chmod +x "$formula_open_root/bin/"*

    PATH="$formula_open_root/bin:$PATH" BASH_ENV="$formula_open_root/bash-env" \
        "$formula_open_root/timezoner-install-app" "$formula_open_root/Applications" --open \
        > "$formula_open_root/output" 2>&1 || {
            sed -n '1,120p' "$formula_open_root/output" >&2
            fail "Homebrew update-open failed"
        }
    test -f "$TZ_TEST_KILLED" || fail "Homebrew helper did not stop the installed process"
    test -f "$TZ_TEST_OPENED" || fail "Homebrew helper did not launch the installed bundle"
fi

echo "install lifecycle checks passed"
