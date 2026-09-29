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
if [[ -d "$DESTINATION" ]]; then
    canonical_destination_parent="$(cd -P "$DESTINATION" && pwd -P)"
    if [[ "$canonical_source_parent" == "$canonical_destination_parent" ]] || \
       { [[ -e "$APP_SOURCE" && -e "$APP_DESTINATION" ]] && \
         [[ "$(realpath "$APP_SOURCE")" == "$(realpath "$APP_DESTINATION")" ]]; }; then
        echo "error: install destination is the source app bundle" >&2
        exit 64
    fi
fi

running_installed_pids() {
    local executable="$1"
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
    done < <(ps -axo pid=,comm=)
}

stop_installed_app() {
    local executable="$1"
    local pid remaining attempt
    remaining="$(running_installed_pids "$executable")"
    [[ -n "$remaining" ]] || return 0

    while IFS= read -r pid; do
        [[ -n "$pid" ]] && kill -TERM "$pid"
    done <<< "$remaining"

    for ((attempt = 0; attempt < 50; attempt++)); do
        remaining="$(running_installed_pids "$executable")"
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
if [[ "$OPEN_APP" -eq 1 ]]; then
    installed_executable="$(cd -P "$DESTINATION" && pwd -P)/${APP_NAME}.app/Contents/MacOS/TimeZoner"
    stop_installed_app "$installed_executable"
fi
rm -rf "$APP_DESTINATION"
cp -R "$APP_SOURCE" "$APP_DESTINATION"
codesign --force --sign - "$APP_DESTINATION"
codesign --verify "$APP_DESTINATION"

echo "Installed TimeZoner.app to $APP_DESTINATION"
echo "Launch it with:"
echo "  open \"$APP_DESTINATION\""

if [[ "$OPEN_APP" -eq 1 ]]; then
    open "$APP_DESTINATION"
fi
