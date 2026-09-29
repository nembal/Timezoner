#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="TimeZoner"
DESTINATION="$HOME/Applications"
OPEN_APP=0
SKIP_BUILD=0
DRY_RUN=0

usage() {
    cat <<'USAGE'
Usage: ./install.sh [options]

Build and install TimeZoner.app locally.

Options:
  --destination PATH  Install TimeZoner.app under PATH
  --applications      Install to /Applications
  --open              Open TimeZoner.app after install
  --skip-build        Install the existing app/TimeZoner.app
  --dry-run           Print the planned actions without building or copying
  -h, --help          Show this help
USAGE
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: required command not found: $command_name" >&2
        exit 1
    fi
}

verify_app_bundle() {
    local app_path="$1"
    local executable_path="$app_path/Contents/MacOS/TimeZoner"
    local info_plist_path="$app_path/Contents/Info.plist"
    local resource_bundle_path="$app_path/Contents/Resources/TimeZoner_TimeZonerLib.bundle"
    local resource_path="$resource_bundle_path/Contents/Resources/timezone-boundaries.json"

    if [[ ! -x "$executable_path" ]]; then
        echo "error: missing executable: $executable_path" >&2
        exit 1
    fi

    if [[ ! -f "$info_plist_path" ]]; then
        echo "error: missing Info.plist: $info_plist_path" >&2
        exit 1
    fi

    if [[ ! -f "$resource_path" && ! -f "$resource_bundle_path/timezone-boundaries.json" ]]; then
        echo "error: missing resource JSON: $resource_path" >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --destination)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "error: --destination requires a path" >&2
                exit 64
            fi
            DESTINATION="$2"
            shift 2
            ;;
        --destination=*)
            DESTINATION="${1#*=}"
            shift
            ;;
        --applications)
            DESTINATION="/Applications"
            shift
            ;;
        --open)
            OPEN_APP=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

APP_SOURCE="$ROOT/app/${APP_NAME}.app"
APP_DESTINATION="$DESTINATION/${APP_NAME}.app"

canonical_source_parent="$(cd -P "$ROOT/app" && pwd -P)"
reject_source_destination() {
    local canonical_destination_parent
    [[ -d "$DESTINATION" ]] || return 0
    canonical_destination_parent="$(cd -P "$DESTINATION" && pwd -P)"
    if [[ "$canonical_source_parent" == "$canonical_destination_parent" ]] || \
       { [[ -e "$APP_SOURCE" && -e "$APP_DESTINATION" ]] && \
         [[ "$(realpath "$APP_SOURCE")" == "$(realpath "$APP_DESTINATION")" ]]; }; then
        echo "error: install destination is the source app bundle" >&2
        exit 64
    fi
}

reject_source_destination

read_process_snapshot() {
    local snapshot
    if ! snapshot="$(ps -axo pid=,comm=)"; then
        echo "error: process query failed; refusing to replace TimeZoner.app" >&2
        return 1
    fi
    printf '%s\n' "$snapshot"
}

running_installed_pids() {
    local executable="$1"
    local snapshot="$2"
    local line pid command
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.+)$ ]]; then
            pid="${BASH_REMATCH[1]}"
            command="${BASH_REMATCH[2]}"
            if [[ "$command" == "$executable" ]] || \
               { [[ -e "$command" ]] && [[ "$(realpath "$command")" == "$executable" ]]; }; then
                printf '%s\n' "$pid"
            fi
        fi
    done <<< "$snapshot"
}

running_other_timezoner_executables() {
    local installed_executable="$1"
    local snapshot="$2"
    local line command bundle_path bundle_id
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*[0-9]+[[:space:]]+(.+)$ ]] || continue
        command="${BASH_REMATCH[1]}"
        [[ "$command" == *.app/Contents/MacOS/TimeZoner ]] || continue
        [[ "$command" == "$installed_executable" ]] && continue
        if [[ -e "$command" ]] && [[ "$(realpath "$command")" == "$installed_executable" ]]; then
            continue
        fi
        bundle_path="${command%/Contents/MacOS/TimeZoner}"
        if [[ -f "$bundle_path/Contents/Info.plist" ]]; then
            bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$bundle_path/Contents/Info.plist" 2>/dev/null || true)"
            [[ "$bundle_id" == "com.timezoner.app" ]] || continue
        fi
        printf '%s\n' "$command"
    done <<< "$snapshot"
}

stop_installed_app() {
    local executable="$1"
    local snapshot="$2"
    local pid remaining attempt
    remaining="$(running_installed_pids "$executable" "$snapshot")"
    [[ -n "$remaining" ]] || return 0

    while IFS= read -r pid; do
        [[ -n "$pid" ]] && kill -TERM "$pid"
    done <<< "$remaining"

    for ((attempt = 0; attempt < 50; attempt++)); do
        snapshot="$(read_process_snapshot)" || exit 1
        remaining="$(running_installed_pids "$executable" "$snapshot")"
        [[ -z "$remaining" ]] && return 0
        sleep 0.1
    done
    echo "error: timed out waiting for installed TimeZoner to quit: $executable" >&2
    exit 1
}

if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$SKIP_BUILD" -eq 1 ]]; then
        echo "Would build TimeZoner.app locally: skipped by --skip-build"
    else
        echo "Would build TimeZoner.app locally"
    fi
    echo "Would install TimeZoner.app to $APP_DESTINATION"
    if [[ "$OPEN_APP" -eq 1 ]]; then
        echo "Would open $APP_DESTINATION"
    fi
    exit 0
fi

require_command codesign

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    require_command swift
    bash "$ROOT/scripts/build.sh"
fi

if [[ ! -d "$APP_SOURCE" ]]; then
    echo "error: expected app bundle not found: $APP_SOURCE" >&2
    echo "Run ./scripts/build.sh first, or omit --skip-build." >&2
    exit 1
fi

verify_app_bundle "$APP_SOURCE"

mkdir -p "$DESTINATION"
reject_source_destination
require_command plutil
stage_dir="$(mktemp -d "$DESTINATION/.TimeZoner-install.XXXXXX")"
staged_app="$stage_dir/TimeZoner.app"
previous_app="$stage_dir/previous.app"
cleanup_install() {
    local status=$?
    trap - EXIT
    if [[ -e "$previous_app" || -L "$previous_app" ]]; then
        if [[ ! -e "$APP_DESTINATION" && ! -L "$APP_DESTINATION" ]]; then
            if ! mv "$previous_app" "$APP_DESTINATION"; then
                echo "error: could not restore the previous app; it remains at $previous_app" >&2
                exit 1
            fi
        fi
    fi
    rm -rf "$stage_dir"
    exit "$status"
}
trap cleanup_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
cp -R "$APP_SOURCE" "$staged_app"
codesign --force --sign - "$staged_app"
codesign --verify "$staged_app"
installed_executable="$(cd -P "$DESTINATION" && pwd -P)/${APP_NAME}.app/Contents/MacOS/TimeZoner"
process_snapshot="$(read_process_snapshot)" || exit 1
other_executables="$(running_other_timezoner_executables "$installed_executable" "$process_snapshot")"
if [[ -n "$other_executables" ]]; then
    echo "error: another TimeZoner copy is running at $other_executables; quit it before updating" >&2
    exit 1
fi
stop_installed_app "$installed_executable" "$process_snapshot"
if [[ -e "$APP_DESTINATION" || -L "$APP_DESTINATION" ]]; then
    mv "$APP_DESTINATION" "$previous_app"
fi
mv "$staged_app" "$APP_DESTINATION"

echo "Installed TimeZoner.app to $APP_DESTINATION"
echo "Launch it with:"
echo "  open \"$APP_DESTINATION\""

if [[ "$OPEN_APP" -eq 1 ]]; then
    open "$APP_DESTINATION"
fi
