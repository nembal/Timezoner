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
    open|formula|formula-open)
        ;;
    *)
        fail "unknown case: $1"
        ;;
esac

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
        'printf "52525 /Applications/TimeZoner.app/Contents/MacOS/TimeZoner\n"' \
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
        'printf "52525 /Applications/TimeZoner.app/Contents/MacOS/TimeZoner\n"' \
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
