# frozen_string_literal: true

# Homebrew formula for TimeZoner.
class Timezoner < Formula
  desc "Lightweight macOS floating-panel app for instant timezone conversion"
  homepage "https://github.com/nembal/Timezoner"
  url "https://github.com/nembal/Timezoner/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "b2ee6fe0b0f87eae1fa036f44f46d820f5b9f123ff1aaab614714609869f92ce"
  license "MIT"
  head "https://github.com/nembal/Timezoner.git", branch: "main"

  depends_on :macos

  def install
    developer_dir = Utils.safe_popen_read("xcode-select", "-p").chomp
    if developer_dir.include?("/Library/Developer/CommandLineTools")
      system "bash", "app/fix-spm.sh"
      ENV["SWIFT_EXEC"] = "/tmp/spm-fix/swiftc-wrapper.sh"
    end

    system "swift", "build", "-c", "release", "--package-path", "app", "--product", "TimeZoner"

    app_bundle = prefix/"TimeZoner.app"
    (app_bundle/"Contents/MacOS").mkpath
    (app_bundle/"Contents/Resources").mkpath
    cp "app/.build/release/TimeZoner", app_bundle/"Contents/MacOS/TimeZoner"
    cp "app/Info.plist", app_bundle/"Contents/Info.plist"
    system "codesign", "--force", "--sign", "-", app_bundle

    (bin/"timezoner").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      open "#{prefix}/TimeZoner.app"
    EOS

    (bin/"timezoner-install-app").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      destination="${1:-/Applications}"
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

      Install a copy into /Applications:
        timezoner-install-app

      Then launch it from /Applications, Spotlight, or:
        open /Applications/TimeZoner.app
    EOS
  end

  test do
    assert_path_exists prefix/"TimeZoner.app/Contents/MacOS/TimeZoner"
    system "codesign", "--verify", prefix/"TimeZoner.app"
  end
end
