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
    open|formula|formula-open|open-failure|formula-open-failure|crosspath|formula-crosspath|default|formula-default|ps-failure|formula-ps-failure|stale-path|formula-stale-path|copy-failure|formula-copy-failure|sign-failure|formula-sign-failure|promote-failure|formula-promote-failure|restore-conflict|formula-restore-conflict|concurrent|formula-concurrent)
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
    if PATH="$formula_conflict_root/bin:$PATH" BASH_ENV="$formula_conflict_root/bash-env" \
        "$formula_conflict_root/timezoner-install-app" "$formula_conflict_root/Applications" \
        > "$formula_conflict_root/default-output" 2>&1; then
        fail "Homebrew default update replaced a bundle while another copy was running"
    fi
    [[ "$(< "$formula_conflict_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
        fail "Homebrew default conflict replaced the installed bundle"
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

if [[ "${1:-all}" == "default" || "${1:-all}" == "formula-default" || "${1:-all}" == "all" ]]; then
    for install_kind in source formula; do
        [[ "${1:-all}" == "all" || ( "${1:-all}" == "default" && "$install_kind" == "source" ) || ( "${1:-all}" == "formula-default" && "$install_kind" == "formula" ) ]] || continue
        default_root="$test_root/$install_kind-default"
        make_source_bundle "$default_root"
        mkdir -p "$default_root/Applications/TimeZoner.app/Contents/MacOS" "$default_root/bin"
        printf 'old binary\n' > "$default_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        chmod +x "$default_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        if [[ "$install_kind" == "formula" ]]; then
            mkdir -p "$default_root/prefix"
            cp -R "$default_root/app/TimeZoner.app" "$default_root/prefix/TimeZoner.app"
            write_formula_helper "$default_root/prefix" "$default_root/timezoner-install-app"
            installer="$default_root/timezoner-install-app"
        else
            installer="$default_root/install.sh"
        fi
        export TZ_TEST_DESTINATION="$default_root/Applications/TimeZoner.app"
        export TZ_TEST_KILLED="$default_root/killed"
        export TZ_TEST_OPENED="$default_root/opened"
        printf '#!/bin/bash\nexit 0\n' > "$default_root/bin/codesign"
        printf '%s\n' '#!/bin/bash' \
            'if [[ ! -f "$TZ_TEST_KILLED" ]]; then' \
            '  printf "42424 %s/Contents/MacOS/TimeZoner\n" "$TZ_TEST_DESTINATION"' \
            'fi' > "$default_root/bin/ps"
        printf '#!/bin/bash\ntouch "$TZ_TEST_OPENED"\n' > "$default_root/bin/open"
        printf '%s\n' 'kill() {' \
            '  [[ "$1" == "-TERM" && "$2" == "42424" ]] || return 1' \
            '  [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "old binary" ]] || return 1' \
            '  touch "$TZ_TEST_KILLED"' \
            '}' > "$default_root/bash-env"
        chmod +x "$default_root/bin/"*
        if [[ "$install_kind" == "formula" ]]; then
            PATH="$default_root/bin:$PATH" BASH_ENV="$default_root/bash-env" \
                "$installer" "$default_root/Applications" > "$default_root/output" 2>&1 || fail "Homebrew default update failed"
        else
            PATH="$default_root/bin:$PATH" BASH_ENV="$default_root/bash-env" \
                "$installer" --skip-build --destination "$default_root/Applications" > "$default_root/output" 2>&1 || fail "source default update failed"
        fi
        test -f "$TZ_TEST_KILLED" || fail "$install_kind default update replaced a running bundle without stopping it"
        test ! -f "$TZ_TEST_OPENED" || fail "$install_kind default update launched the app without --open"
        [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "new binary" ]] || fail "$install_kind default update did not copy the new bundle"
    done
fi

if [[ "${1:-all}" == "copy-failure" || "${1:-all}" == "formula-copy-failure" || \
      "${1:-all}" == "sign-failure" || "${1:-all}" == "formula-sign-failure" || \
      "${1:-all}" == "all" ]]; then
    for scenario in copy-failure sign-failure; do
        for install_kind in source formula; do
            selected_case="$scenario"
            [[ "$install_kind" == "source" ]] || selected_case="formula-$scenario"
            [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
            fixture_root="$test_root/$selected_case"
            make_source_bundle "$fixture_root"
            mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
            printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
            chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
            if [[ "$install_kind" == "formula" ]]; then
                mkdir -p "$fixture_root/prefix"
                cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
                write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
                installer="$fixture_root/timezoner-install-app"
            else
                installer="$fixture_root/install.sh"
            fi
            export TZ_TEST_DESTINATION="$fixture_root/Applications/TimeZoner.app"
            export TZ_TEST_KILLED="$fixture_root/killed"
            printf '%s\n' '#!/bin/bash' \
                'printf "42424 %s/Contents/MacOS/TimeZoner\n" "$TZ_TEST_DESTINATION"' > "$fixture_root/bin/ps"
            printf '%s\n' 'kill() { touch "$TZ_TEST_KILLED"; }' > "$fixture_root/bash-env"
            if [[ "$scenario" == "copy-failure" ]]; then
                printf '%s\n' '#!/bin/bash' \
                    '/bin/cp "$@"' \
                    'echo "fixture copy failed" >&2' \
                    'exit 81' > "$fixture_root/bin/cp"
                printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/codesign"
            else
                printf '%s\n' '#!/bin/bash' \
                    'if [[ "$1" == "--force" ]]; then' \
                    '  echo "fixture signing failed" >&2' \
                    '  exit 82' \
                    'fi' \
                    'exit 0' > "$fixture_root/bin/codesign"
            fi
            chmod +x "$fixture_root/bin/"*
            if [[ "$install_kind" == "formula" ]]; then
                if PATH="$fixture_root/bin:$PATH" BASH_ENV="$fixture_root/bash-env" \
                    "$installer" "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                    fail "$selected_case reported success"
                fi
            else
                if PATH="$fixture_root/bin:$PATH" BASH_ENV="$fixture_root/bash-env" \
                    "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                    fail "$selected_case reported success"
                fi
            fi
            [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
                fail "$selected_case damaged the existing app"
            test ! -f "$TZ_TEST_KILLED" || fail "$selected_case stopped the working app before staging completed"
            for leftover in "$fixture_root/Applications"/.TimeZoner-install.??????; do
                test ! -e "$leftover" || fail "$selected_case left a staging directory"
            done
            if [[ "$scenario" == "copy-failure" ]]; then
                grep -F 'fixture copy failed' "$fixture_root/output" >/dev/null || fail "$selected_case did not reach copy"
            else
                grep -F 'fixture signing failed' "$fixture_root/output" >/dev/null || fail "$selected_case did not reach signing"
            fi
        done
    done
fi

if [[ "${1:-all}" == "promote-failure" || "${1:-all}" == "formula-promote-failure" || \
      "${1:-all}" == "all" ]]; then
    for install_kind in source formula; do
        selected_case="promote-failure"
        [[ "$install_kind" == "source" ]] || selected_case="formula-promote-failure"
        [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
        fixture_root="$test_root/$selected_case"
        make_source_bundle "$fixture_root"
        mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
        printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        if [[ "$install_kind" == "formula" ]]; then
            mkdir -p "$fixture_root/prefix"
            cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
            write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
            installer="$fixture_root/timezoner-install-app"
        else
            installer="$fixture_root/install.sh"
        fi
        export TZ_TEST_DESTINATION="$fixture_root/Applications/TimeZoner.app"
        export TZ_TEST_KILLED="$fixture_root/killed"
        export TZ_TEST_RESTARTED="$fixture_root/restarted"
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/codesign"
        printf '%s\n' '#!/bin/bash' \
            'if [[ ! -f "$TZ_TEST_KILLED" ]]; then' \
            '  printf "42424 %s/Contents/MacOS/TimeZoner\n" "$TZ_TEST_DESTINATION"' \
            'fi' > "$fixture_root/bin/ps"
        printf '%s\n' '#!/bin/bash' \
            '[[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "old binary" ]] || exit 1' \
            'touch "$TZ_TEST_RESTARTED"' > "$fixture_root/bin/open"
        printf '%s\n' 'kill() { touch "$TZ_TEST_KILLED"; }' > "$fixture_root/bash-env"
        printf '%s\n' '#!/bin/bash' \
            'if [[ "$1" == */.TimeZoner-install.*/TimeZoner.app ]]; then' \
            '  echo "fixture promotion failed" >&2' \
            '  exit 83' \
            'fi' \
            '/bin/mv "$@"' > "$fixture_root/bin/mv"
        chmod +x "$fixture_root/bin/"*
        if [[ "$install_kind" == "formula" ]]; then
            if PATH="$fixture_root/bin:$PATH" BASH_ENV="$fixture_root/bash-env" "$installer" "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported success"
            fi
        else
            if PATH="$fixture_root/bin:$PATH" BASH_ENV="$fixture_root/bash-env" "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported success"
            fi
        fi
        [[ "$(< "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
            fail "$selected_case failed to restore the previous app"
        test -f "$TZ_TEST_KILLED" || fail "$selected_case did not stop the running old app"
        test -f "$TZ_TEST_RESTARTED" || fail "$selected_case did not restart the restored old app"
        for leftover in "$fixture_root/Applications"/.TimeZoner-install.??????; do
            test ! -e "$leftover" || fail "$selected_case left a staging directory"
        done
        grep -F 'fixture promotion failed' "$fixture_root/output" >/dev/null || fail "$selected_case did not reach promotion"
    done
fi

if [[ "${1:-all}" == "ps-failure" || "${1:-all}" == "formula-ps-failure" || \
      "${1:-all}" == "stale-path" || "${1:-all}" == "formula-stale-path" || "${1:-all}" == "all" ]]; then
    for scenario in ps-failure stale-path; do
        for install_kind in source formula; do
            selected_case="$scenario"
            [[ "$install_kind" == "source" ]] || selected_case="formula-$scenario"
            [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
            fixture_root="$test_root/$selected_case"
            make_source_bundle "$fixture_root"
            mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
            printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
            chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
            if [[ "$install_kind" == "formula" ]]; then
                mkdir -p "$fixture_root/prefix"
                cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
                write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
                installer="$fixture_root/timezoner-install-app"
            else
                installer="$fixture_root/install.sh"
            fi
            printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/codesign"
            if [[ "$scenario" == "ps-failure" ]]; then
                printf '#!/bin/bash\nprintf "52525 /Applications/Unrelated.app/Contents/MacOS/Unrelated\\n"\necho "fixture process query failed" >&2\nexit 9\n' > "$fixture_root/bin/ps"
            else
                mkdir -p "$fixture_root/OtherApplications/OldTimeZoner.app/Contents/MacOS"
                cp "$repo_root/app/Info.plist" "$fixture_root/OtherApplications/OldTimeZoner.app/Contents/Info.plist"
                export TZ_TEST_OTHER_EXECUTABLE="$fixture_root/OtherApplications/OldTimeZoner.app/Contents/MacOS/TimeZoner"
                printf '%s\n' '#!/bin/bash' \
                    'printf "52525 %s\n" "$TZ_TEST_OTHER_EXECUTABLE"' > "$fixture_root/bin/ps"
            fi
            chmod +x "$fixture_root/bin/"*
            if [[ "$install_kind" == "formula" ]]; then
                if PATH="$fixture_root/bin:$PATH" "$installer" "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                    fail "$selected_case accepted unsafe replacement"
                fi
            else
                if PATH="$fixture_root/bin:$PATH" "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                    fail "$selected_case accepted unsafe replacement"
                fi
            fi
            [[ "$(< "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "old binary" ]] || \
                fail "$selected_case replaced the destination before rejecting"
            if [[ "$scenario" == "ps-failure" ]]; then
                grep -F -- "process query" "$fixture_root/output" >/dev/null || fail "$selected_case did not report the process query failure"
            else
                grep -F -- "$TZ_TEST_OTHER_EXECUTABLE" "$fixture_root/output" >/dev/null || fail "$selected_case did not identify the stale running path"
            fi
        done
    done
fi

if [[ "${1:-all}" == "open-failure" || "${1:-all}" == "formula-open-failure" || "${1:-all}" == "all" ]]; then
    for install_kind in source formula; do
        selected_case="open-failure"
        [[ "$install_kind" == "source" ]] || selected_case="formula-open-failure"
        [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
        fixture_root="$test_root/$selected_case"
        make_source_bundle "$fixture_root"
        mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
        printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        if [[ "$install_kind" == "formula" ]]; then
            mkdir -p "$fixture_root/prefix"
            cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
            write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
            installer="$fixture_root/timezoner-install-app"
        else
            installer="$fixture_root/install.sh"
        fi
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/codesign"
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/ps"
        printf '%s\n' '#!/bin/bash' \
            'echo "fixture launch failed" >&2' \
            'exit 91' > "$fixture_root/bin/open"
        chmod +x "$fixture_root/bin/"*
        if [[ "$install_kind" == "formula" ]]; then
            if PATH="$fixture_root/bin:$PATH" "$installer" "$fixture_root/Applications" --open > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported successful launch"
            fi
        else
            if PATH="$fixture_root/bin:$PATH" "$installer" --skip-build --destination "$fixture_root/Applications" --open > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported successful launch"
            fi
        fi
        [[ "$(< "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner")" == "new binary" ]] || \
            fail "$selected_case rolled back a completed installation"
        grep -F 'installed but could not open' "$fixture_root/output" >/dev/null || \
            fail "$selected_case did not explain that installation succeeded"
    done
fi

if [[ "${1:-all}" == "restore-conflict" || "${1:-all}" == "formula-restore-conflict" || "${1:-all}" == "all" ]]; then
    for install_kind in source formula; do
        selected_case="restore-conflict"
        [[ "$install_kind" == "source" ]] || selected_case="formula-restore-conflict"
        [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
        fixture_root="$test_root/$selected_case"
        make_source_bundle "$fixture_root"
        mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
        printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        if [[ "$install_kind" == "formula" ]]; then
            mkdir -p "$fixture_root/prefix"
            cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
            write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
            installer="$fixture_root/timezoner-install-app"
        else
            installer="$fixture_root/install.sh"
        fi
        export TZ_TEST_DESTINATION="$fixture_root/Applications/TimeZoner.app"
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/codesign"
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/ps"
        printf '%s\n' '#!/bin/bash' \
            'if [[ "$1" == */.TimeZoner-install.*/TimeZoner.app && "$2" == "$TZ_TEST_DESTINATION" ]]; then' \
            '  mkdir "$TZ_TEST_DESTINATION"' \
            '  echo "fixture destination conflict" >&2' \
            '  exit 83' \
            'fi' \
            '/bin/mv "$@"' > "$fixture_root/bin/mv"
        chmod +x "$fixture_root/bin/"*
        if [[ "$install_kind" == "formula" ]]; then
            if PATH="$fixture_root/bin:$PATH" "$installer" "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported success"
            fi
        else
            if PATH="$fixture_root/bin:$PATH" "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/output" 2>&1; then
                fail "$selected_case reported success"
            fi
        fi
        recovered=0
        for old_bundle in "$fixture_root/Applications"/.TimeZoner-install.*/previous.app; do
            if [[ -f "$old_bundle/Contents/MacOS/TimeZoner" ]] && \
               [[ "$(< "$old_bundle/Contents/MacOS/TimeZoner")" == "old binary" ]]; then
                recovered=1
            fi
        done
        [[ "$recovered" -eq 1 ]] || fail "$selected_case deleted the previous app after rollback was blocked"
        grep -F 'could not restore' "$fixture_root/output" >/dev/null || fail "$selected_case did not explain the recovery path"
    done
fi

if [[ "${1:-all}" == "concurrent" || "${1:-all}" == "formula-concurrent" || "${1:-all}" == "all" ]]; then
    for install_kind in source formula; do
        selected_case="concurrent"
        [[ "$install_kind" == "source" ]] || selected_case="formula-concurrent"
        [[ "${1:-all}" == "all" || "${1:-all}" == "$selected_case" ]] || continue
        fixture_root="$test_root/$selected_case"
        make_source_bundle "$fixture_root"
        mkdir -p "$fixture_root/Applications/TimeZoner.app/Contents/MacOS" "$fixture_root/bin"
        printf 'old binary\n' > "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        chmod +x "$fixture_root/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
        if [[ "$install_kind" == "formula" ]]; then
            mkdir -p "$fixture_root/prefix"
            cp -R "$fixture_root/app/TimeZoner.app" "$fixture_root/prefix/TimeZoner.app"
            write_formula_helper "$fixture_root/prefix" "$fixture_root/timezoner-install-app"
            installer="$fixture_root/timezoner-install-app"
        else
            installer="$fixture_root/install.sh"
        fi
        export TZ_TEST_DESTINATION="$fixture_root/Applications/TimeZoner.app"
        export TZ_TEST_FIRST_MOVED="$fixture_root/first-moved"
        export TZ_TEST_RELEASE="$fixture_root/release-first"
        export TZ_TEST_SECOND_SIGNED="$fixture_root/second-signed"
        printf '#!/bin/bash\nexit 0\n' > "$fixture_root/bin/ps"
        printf '%s\n' '#!/bin/bash' \
            '[[ "$TZ_TEST_ROLE" == second ]] && touch "$TZ_TEST_SECOND_SIGNED"' \
            'exit 0' > "$fixture_root/bin/codesign"
        printf '%s\n' '#!/bin/bash' \
            'if [[ "$TZ_TEST_ROLE" == first && "$1" == "$TZ_TEST_DESTINATION" && "$2" == */previous.app ]]; then' \
            '  /bin/mv "$@" || exit' \
            '  touch "$TZ_TEST_FIRST_MOVED"' \
            '  while [[ ! -f "$TZ_TEST_RELEASE" ]]; do sleep 0.05; done' \
            '  exit 0' \
            'fi' \
            '/bin/mv "$@"' > "$fixture_root/bin/mv"
        chmod +x "$fixture_root/bin/"*

        if [[ "$install_kind" == "formula" ]]; then
            PATH="$fixture_root/bin:$PATH" TZ_TEST_ROLE=first "$installer" "$fixture_root/Applications" > "$fixture_root/first-output" 2>&1 &
        else
            PATH="$fixture_root/bin:$PATH" TZ_TEST_ROLE=first "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/first-output" 2>&1 &
        fi
        first_pid=$!
        for ((attempt = 0; attempt < 100; attempt++)); do
            [[ -f "$TZ_TEST_FIRST_MOVED" ]] && break
            sleep 0.05
        done
        if [[ ! -f "$TZ_TEST_FIRST_MOVED" ]]; then
            touch "$TZ_TEST_RELEASE"
            wait "$first_pid" || true
            fail "$selected_case did not reach the promotion gap"
        fi
        if [[ "$install_kind" == "formula" ]]; then
            PATH="$fixture_root/bin:$PATH" TZ_TEST_ROLE=second "$installer" "$fixture_root/Applications" > "$fixture_root/second-output" 2>&1 &
        else
            PATH="$fixture_root/bin:$PATH" TZ_TEST_ROLE=second "$installer" --skip-build --destination "$fixture_root/Applications" > "$fixture_root/second-output" 2>&1 &
        fi
        second_pid=$!
        for ((attempt = 0; attempt < 60; attempt++)); do
            [[ -f "$TZ_TEST_SECOND_SIGNED" ]] && break
            sleep 0.05
        done
        second_overlapped=0
        [[ ! -f "$TZ_TEST_SECOND_SIGNED" ]] || second_overlapped=1
        touch "$TZ_TEST_RELEASE"
        first_status=0
        second_status=0
        wait "$first_pid" || first_status=$?
        wait "$second_pid" || second_status=$?
        [[ "$second_overlapped" -eq 0 ]] || fail "$selected_case signed another update while the first promotion was incomplete"
        [[ "$first_status" -eq 0 && "$second_status" -eq 0 ]] || fail "$selected_case failed to complete both updates"
        [[ "$(< "$TZ_TEST_DESTINATION/Contents/MacOS/TimeZoner")" == "new binary" ]] || fail "$selected_case did not leave an intact app"
        test ! -e "$TZ_TEST_DESTINATION/TimeZoner.app" || fail "$selected_case nested one app inside another"
        for leftover in "$fixture_root/Applications"/.TimeZoner-install.??????; do
            test ! -d "$leftover" || fail "$selected_case left a staging directory"
        done
    done
fi

echo "install lifecycle checks passed"
