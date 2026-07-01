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

    resource_bundle = Dir["app/.build/**/release/TimeZoner_TimeZonerLib.bundle"].first
    odie "TimeZoner_TimeZonerLib.bundle not found under app/.build" if resource_bundle.blank?

    app_bundle = prefix/"TimeZoner.app"
    (app_bundle/"Contents/MacOS").mkpath
    (app_bundle/"Contents/Resources").mkpath
    cp "app/.build/release/TimeZoner", app_bundle/"Contents/MacOS/TimeZoner"
    cp "app/Info.plist", app_bundle/"Contents/Info.plist"
    cp_r resource_bundle, app_bundle/"Contents/Resources/TimeZoner_TimeZonerLib.bundle"
    system "codesign", "--force", "--sign", "-", app_bundle

    (bin/"timezoner").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      open "#{prefix}/TimeZoner.app"
    EOS

    (bin/"timezoner-install-app").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      destination="${1:-$HOME/Applications}"
      mkdir -p "$destination"
      rm -rf "$destination/TimeZoner.app"
      cp -R "#{prefix}/TimeZoner.app" "$destination/TimeZoner.app"
      codesign --force --sign - "$destination/TimeZoner.app"
      echo "Installed TimeZoner.app to $destination/TimeZoner.app"
      echo "Launch with: open $destination/TimeZoner.app"
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

      Install explicitly into /Applications:
        timezoner-install-app /Applications

      Then launch it from ~/Applications, Spotlight, or:
        open ~/Applications/TimeZoner.app
    EOS
  end

  test do
    resource_json = prefix/"TimeZoner.app/Contents/Resources/TimeZoner_TimeZonerLib.bundle/timezone-boundaries.json"

    assert_predicate prefix/"TimeZoner.app/Contents/MacOS/TimeZoner", :executable?
    assert_path_exists prefix/"TimeZoner.app/Contents/Info.plist"
    assert_path_exists resource_json
    system "codesign", "--verify", prefix/"TimeZoner.app"
  end
end
