# frozen_string_literal: true

# Homebrew formula for TimeZoner.
class Timezoner < Formula
  desc "Lightweight macOS floating-panel app for instant timezone conversion"
  homepage "https://github.com/nembal/Timezoner"
  url "https://github.com/nembal/Timezoner/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "59c129efb6900881f55d6187f372cac6f154321be2de474b6427732febfe357c"
  license "MIT"
  head "https://github.com/nembal/Timezoner.git", branch: "main"

  depends_on macos: :sonoma

  def install
    developer_dir = Utils.safe_popen_read("xcode-select", "-p").chomp
    if developer_dir.include?("/Library/Developer/CommandLineTools")
      system "bash", "app/fix-spm.sh"
      ENV["SWIFT_EXEC"] = "/tmp/spm-fix/swiftc-wrapper.sh"
    end

    system "swift", "build", "--disable-sandbox", "-c", "release", "--package-path", "app", "--product", "TimeZoner"

    release_products_dir = Utils.safe_popen_read("swift", "build", "--disable-sandbox", "-c", "release", "--package-path", "app", "--show-bin-path").chomp
    resource_bundle = Pathname.new(release_products_dir)/"TimeZoner_TimeZonerLib.bundle"
    resource_json = resource_bundle/"Contents/Resources/timezone-boundaries.json"
    odie "TimeZoner_TimeZonerLib.bundle not found in #{release_products_dir}" unless resource_bundle.directory?
    odie "timezone-boundaries.json not found in #{resource_bundle}" unless resource_json.file?

    app_bundle = prefix/"TimeZoner.app"
    (app_bundle/"Contents/MacOS").mkpath
    (app_bundle/"Contents/Resources").mkpath
    cp Pathname.new(release_products_dir)/"TimeZoner", app_bundle/"Contents/MacOS/TimeZoner"
    cp "app/Info.plist", app_bundle/"Contents/Info.plist"
    cp_r resource_bundle, app_bundle/"Contents/Resources/TimeZoner_TimeZonerLib.bundle"
    plist = app_bundle/"Contents/Info.plist"
    read_plist_value = lambda do |key|
      IO.popen(["/usr/libexec/PlistBuddy", "-c", "Print :#{key}", plist.to_s], err: File::NULL, &:read).strip
    end
    bundle_version = read_plist_value.call("CFBundleShortVersionString")
    build_version = read_plist_value.call("CFBundleVersion")
    if bundle_version.empty? && build_version.empty?
      # The v0.3.0 tagged source predates version keys; its tag is the fallback.
      bundle_version = version.to_s
      system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleShortVersionString string #{bundle_version}", plist
      system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleVersion string #{bundle_version}", plist
      build_version = bundle_version
    end
    odie "Info.plist has inconsistent version metadata" unless bundle_version.match?(/\A\d+\.\d+\.\d+\z/) &&
                                                              build_version == bundle_version
    system "codesign", "--force", "--sign", "-", app_bundle

    (bin/"timezoner").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      open "#{prefix}/TimeZoner.app"
    EOS

    (bin/"timezoner-install-app").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      destination="$HOME/Applications"
      destination_set=0
      open_app=0
      for argument in "$@"; do
        case "$argument" in
          --open)
            open_app=1
            ;;
          --*)
            echo "error: unknown option: $argument" >&2
            exit 64
            ;;
          *)
            if [[ "$destination_set" -eq 1 ]]; then
              echo "error: expected one destination directory" >&2
              exit 64
            fi
            destination="$argument"
            destination_set=1
            ;;
        esac
      done

      source_app="#{prefix}/TimeZoner.app"
      source_parent="$(cd -P "#{prefix}" && pwd -P)"
      reject_source_destination() {
        local destination_parent
        [[ -d "$destination" ]] || return 0
        destination_parent="$(cd -P "$destination" && pwd -P)"
        if [[ "$source_parent" == "$destination_parent" ]] || \
           { [[ -e "$source_app" && -e "$destination/TimeZoner.app" ]] && \
             [[ "$(realpath "$source_app")" == "$(realpath "$destination/TimeZoner.app")" ]]; }; then
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
        printf '%s\\n' "$snapshot"
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
              printf '%s\\n' "$pid"
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
          printf '%s\\n' "$command"
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

      mkdir -p "$destination"
      reject_source_destination
      command -v plutil >/dev/null 2>&1 || { echo "error: plutil is required" >&2; exit 1; }
      stage_dir="$(mktemp -d "$destination/.TimeZoner-install.XXXXXX")"
      staged_app="$stage_dir/TimeZoner.app"
      previous_app="$stage_dir/previous.app"
      installed_app="$destination/TimeZoner.app"
      cleanup_install() {
        local status=$?
        trap - EXIT
        if [[ -e "$previous_app" || -L "$previous_app" ]]; then
          if [[ ! -e "$installed_app" && ! -L "$installed_app" ]]; then
            if ! mv "$previous_app" "$installed_app"; then
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
      cp -R "$source_app" "$staged_app"
      codesign --force --sign - "$staged_app"
      codesign --verify "$staged_app"
      installed_executable="$(cd -P "$destination" && pwd -P)/TimeZoner.app/Contents/MacOS/TimeZoner"
      process_snapshot="$(read_process_snapshot)" || exit 1
      other_executables="$(running_other_timezoner_executables "$installed_executable" "$process_snapshot")"
      if [[ -n "$other_executables" ]]; then
        echo "error: another TimeZoner copy is running at $other_executables; quit it before updating" >&2
        exit 1
      fi
      stop_installed_app "$installed_executable" "$process_snapshot"
      if [[ -e "$installed_app" || -L "$installed_app" ]]; then
        mv "$installed_app" "$previous_app"
      fi
      mv "$staged_app" "$installed_app"
      echo "Installed TimeZoner.app to $destination/TimeZoner.app"
      echo "Launch with: open $destination/TimeZoner.app"
      if [[ "$open_app" -eq 1 ]]; then
        open "$destination/TimeZoner.app"
      fi
    EOS

    chmod 0755, bin/"timezoner"
    chmod 0755, bin/"timezoner-install-app"
  end

  def caveats
    <<~EOS
      TimeZoner is built from source and ad-hoc signed locally. It is not Apple-notarized.

      Launch the Homebrew app bundle:
        timezoner

      Install a copy into ~/Applications:
        timezoner-install-app

      After brew upgrade, update the separately copied app in ~/Applications:
        timezoner-install-app

      Update a running installed copy and relaunch it:
        timezoner-install-app --open

      Install explicitly into /Applications:
        timezoner-install-app /Applications

      Then launch it from ~/Applications, Spotlight, or:
        open ~/Applications/TimeZoner.app
    EOS
  end

  test do
    resource_json = prefix/"TimeZoner.app/Contents/Resources/TimeZoner_TimeZonerLib.bundle/Contents/Resources/timezone-boundaries.json"

    assert_predicate prefix/"TimeZoner.app/Contents/MacOS/TimeZoner", :executable?
    assert_path_exists prefix/"TimeZoner.app/Contents/Info.plist"
    assert_path_exists resource_json
    system "codesign", "--verify", prefix/"TimeZoner.app"
  end
end
