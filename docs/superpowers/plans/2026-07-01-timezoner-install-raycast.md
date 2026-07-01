# TimeZoner Install And Raycast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make source-built Homebrew install, `install.sh`, Manual DMG positioning, and the full Raycast extension real and verified.

**Architecture:** Keep TimeZoner local-first and unsigned-by-Apple by making the primary install path build the app on the user's Mac, then ad-hoc sign the local result. Homebrew installs a formula-built `.app` plus small launcher/install helpers; `install.sh` handles clone/source checkout installation; Raycast uses the shared alias data and opens the native app through a `timezoner://` URL scheme.

**Tech Stack:** Bash, Homebrew Formula Ruby, SwiftPM, SwiftUI/AppKit, Raycast API, TypeScript, Vitest.

**Implementation outcome:** Completed on branch `codex/install-raycast-distribution`, merged as PR #2, and released as `v0.3.0`. Final implementation adds a stable Homebrew formula for the tagged release with `--HEAD` fallback, copies the SwiftPM `TimeZoner_TimeZonerLib.bundle` through every app packaging path, hardens deep-link cold-start delivery, and persists Raycast zones in Raycast LocalStorage rather than syncing them with the macOS app.

---

## Requirements

- Interpret the user's "rename the DMV" as "rename the DMG" because this repo has `scripts/create-dmg.sh`, `scripts/dmg-readme.txt`, and a prior proposal to position DMG as the Manual DMG install path.
- Do not require Apple Developer Program, Developer ID, notarization, or Mac App Store.
- Do not tell users that bypassing Gatekeeper is the primary install path.
- Preserve the current zero-network app runtime and bundled alias table.
- Keep the Raycast extension standalone while allowing `Cmd+O` to open TimeZoner with the converted time.
- Verify Swift tests, Raycast tests/build, shell scripts, and Homebrew formula syntax/audit where local tooling permits.
- Preserve the requested process: write this plan first, run one fresh reviewer subagent before implementation, then implement with `superpowers:subagent-driven-development`.

## Current Evidence

- Branch: `main`, clean except untracked `AGENTS.md`.
- Swift baseline: `cd app && swift run TimeZonerTests` passes 150 tests, with one existing warning in `TimezoneMapView.swift`.
- Raycast baseline before `npm ci`: `npm test` fails because `vitest` is missing; `npm run build` fails because `ray` is missing.
- Existing packaging: `scripts/create-dmg.sh` creates an ad-hoc signed DMG and `scripts/dmg-readme.txt` tells users to run `xattr -cr`.
- Existing Raycast files: `raycast/src/convert-time.tsx`, `raycast/src/world-clock.tsx`, `raycast/src/parser.ts`, `raycast/src/formatter.ts`, `raycast/src/aliases.ts`, `raycast/src/types.ts`, generated `raycast/src/data/timezones.ts`, and tests under `raycast/__tests__/`.
- Fresh process-review subagent completed after initial plan draft and found fixable issues around CLT builds, Homebrew executable helpers, `--HEAD` verification, and URL scheme smoke testing. This revision incorporates those findings before implementation.

## File Structure

- Create `install.sh`: user-facing source-build installer. Supports local checkout use, clear help text, default `~/Applications`, optional `--destination`, `--open`, `--dry-run`, and `--skip-build`.
- Modify `scripts/build.sh`: auto-apply `app/fix-spm.sh` when `xcode-select` points at Command Line Tools so source installs work on CLT-only Macs.
- Create `Formula/timezoner.rb`: Homebrew formula that builds `app/` from source, assembles `TimeZoner.app`, ad-hoc signs it, installs `timezoner` and `timezoner-install-app` helper scripts, and documents the tap/install command.
- Create `scripts/test-install.sh`: deterministic shell checks for `install.sh` without installing into real Applications.
- Modify `README.md`: make Homebrew/source-built install primary, rename the DMG path to Manual DMG install, and update Raycast instructions for a finished extension.
- Modify `scripts/dmg-readme.txt`: rename the path to Manual DMG install and make the Gatekeeper bypass a secondary transparent explanation.
- Modify `scripts/create-dmg.sh`: make terminal output say Manual DMG and reference the Homebrew/source-built default.
- Modify `app/Info.plist`: register the `timezoner` URL scheme.
- Create `app/Sources/Utilities/TimeZonerDeepLink.swift`: parse `timezoner://open` and `timezoner://set?hour=15&minute=0&zone=America/Los_Angeles&label=SF`.
- Modify `app/Sources/App/TimeZonerApp.swift`: handle incoming URLs and post deep-link commands to the visible panel.
- Modify `app/Sources/Views/ContentView.swift`: receive deep-link commands, set the shared `TimeState`, add a missing zone when needed, and highlight the target card.
- Create `app/Tests/TimeZonerDeepLinkTests.swift`: prove URL parsing behavior.
- Modify `app/Tests/TimeZonerTests.swift`: call `runTimeZonerDeepLinkTests()`.
- Modify `raycast/src/types.ts`: use a discriminated union for conversion, add-zone, and remove-zone parsed commands.
- Modify `raycast/src/parser.ts`: parse `+Tokyo`, `add Hong Kong`, `-SF`, `remove NYC`, and preserve existing conversion behavior.
- Create `raycast/src/zones.ts`: resolve preferences plus Raycast `LocalStorage` overrides for add/remove zone behavior.
- Create `raycast/src/timezoner-url.ts`: build `timezoner://` URLs from parsed conversion queries.
- Modify `raycast/src/convert-time.tsx`: render add/remove command actions, use persisted zones, and open TimeZoner with the parsed conversion.
- Modify `raycast/src/world-clock.tsx`: use the same persisted zones.
- Modify `raycast/__tests__/parser.test.ts`: cover add/remove command parsing.
- Create `raycast/__tests__/timezoner-url.test.ts`: cover URL building.
- Create `raycast/__tests__/zones.test.ts`: cover zone add/remove helpers without Raycast UI.

---

### Task 1: Isolate Worktree And Reconfirm Baseline

**Files:**
- Modify only if needed: `.gitignore`
- Work in a new worktree or branch: `codex/install-raycast-distribution`

- [ ] **Step 1: Check worktree directory convention**

Run:

```bash
ls -d .worktrees 2>/dev/null
ls -d worktrees 2>/dev/null
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

Expected: if no directory or CLAUDE preference exists, use `.worktrees/` as the default project-local convention.

- [ ] **Step 2: Ensure project-local worktrees are ignored**

Run:

```bash
git check-ignore -q .worktrees || printf '\n.worktrees/\n' >> .gitignore
git check-ignore -q .worktrees
```

Expected: second command exits 0. If `.gitignore` changed, commit it before feature work:

```bash
git add .gitignore
git commit -m "chore: ignore local worktrees"
```

- [ ] **Step 3: Create the implementation worktree**

Run:

```bash
git worktree add .worktrees/install-raycast-distribution -b codex/install-raycast-distribution
cd .worktrees/install-raycast-distribution
```

Expected: branch `codex/install-raycast-distribution` exists and `git status --short` is clean except intentionally copied local-only files if any.

- [ ] **Step 4: Reconfirm Swift baseline**

Run:

```bash
cd app && swift run TimeZonerTests
```

Expected: 150 passed, 0 failed. The existing `isHoveredPolygon` warning may appear and is not part of this task.

- [ ] **Step 5: Install Raycast dependencies**

Run:

```bash
cd raycast && npm ci
```

Expected: dependencies install from `package-lock.json` and `node_modules/.bin/vitest` plus `node_modules/.bin/ray` exist.

---

### Task 2: Add Source-Built `install.sh`

**Files:**
- Create: `install.sh`
- Modify: `scripts/build.sh`
- Create: `scripts/test-install.sh`
- Modify: `README.md`

- [ ] **Step 1: Write shell tests before implementation**

Create `scripts/test-install.sh` with this exact content:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash -n install.sh
bash -n scripts/build.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh
  shellcheck scripts/build.sh
fi

help_output="$(./install.sh --help)"
case "$help_output" in
  *"Usage: ./install.sh"*"--destination"*"--dry-run"*) ;;
  *)
    echo "install.sh help text is missing required options" >&2
    exit 1
    ;;
esac

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

./install.sh --dry-run --skip-build --destination "$tmpdir/Applications" > "$tmpdir/dry-run.log"

grep -q "Would install TimeZoner.app" "$tmpdir/dry-run.log"
grep -q "$tmpdir/Applications/TimeZoner.app" "$tmpdir/dry-run.log"

echo "install.sh checks passed"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
chmod +x scripts/test-install.sh
scripts/test-install.sh
```

Expected: FAIL because `install.sh` does not exist or does not implement the required help/dry-run behavior.

- [ ] **Step 3: Update `scripts/build.sh` for CLT-only Macs**

Replace `scripts/build.sh` with this content so it applies the existing SPM fix wrapper whenever `xcode-select` points at Command Line Tools:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

if xcode-select -p 2>/dev/null | grep -q "/Library/Developer/CommandLineTools"; then
    bash "$ROOT/app/fix-spm.sh" >/dev/null
    export SWIFT_EXEC="/tmp/spm-fix/swiftc-wrapper.sh"
fi

swift build -c release --product TimeZoner

rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/

codesign --force --sign - TimeZoner.app

echo "Built TimeZoner.app (signed ad-hoc)"
```

- [ ] **Step 4: Create `install.sh`**

Create `install.sh` with this exact behavior and implementation:

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="TimeZoner"
DESTINATION="$HOME/Applications"
OPEN_AFTER_INSTALL="false"
DRY_RUN="false"
SKIP_BUILD="false"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Build TimeZoner locally, ad-hoc sign it, and copy it into an Applications folder.
This avoids distributing an unnotarized downloaded binary as the primary install path.

Options:
  --destination PATH   Install into PATH (default: ~/Applications)
  --applications       Install into /Applications
  --open               Open TimeZoner after installing
  --skip-build         Reuse app/TimeZoner.app if it already exists
  --dry-run            Print what would happen without building or copying
  -h, --help           Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --destination)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --destination" >&2
        exit 2
      fi
      DESTINATION="$2"
      shift 2
      ;;
    --applications)
      DESTINATION="/Applications"
      shift
      ;;
    --open)
      OPEN_AFTER_INSTALL="true"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$ROOT/app/${APP_NAME}.app"
TARGET_APP="$DESTINATION/${APP_NAME}.app"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Install Apple's Command Line Tools with: xcode-select --install" >&2
    exit 1
  fi
}

if [ "$DRY_RUN" = "true" ]; then
  echo "Would build ${APP_NAME}.app locally"
  echo "Would install ${APP_NAME}.app to ${TARGET_APP}"
  [ "$OPEN_AFTER_INSTALL" = "true" ] && echo "Would open ${TARGET_APP}"
  exit 0
fi

require_command swift
require_command codesign

if [ "$SKIP_BUILD" != "true" ]; then
  "$ROOT/scripts/build.sh"
fi

if [ ! -d "$APP_BUNDLE" ]; then
  echo "Expected app bundle not found: $APP_BUNDLE" >&2
  echo "Run ./build.sh or omit --skip-build." >&2
  exit 1
fi

mkdir -p "$DESTINATION"
rm -rf "$TARGET_APP"
cp -R "$APP_BUNDLE" "$TARGET_APP"
codesign --force --sign - "$TARGET_APP" >/dev/null

echo "Installed ${APP_NAME}.app to ${TARGET_APP}"
echo "Launch it from Finder, Spotlight, or with: open \"$TARGET_APP\""

if [ "$OPEN_AFTER_INSTALL" = "true" ]; then
  open "$TARGET_APP"
fi
```

- [ ] **Step 5: Run shell checks**

Run:

```bash
chmod +x install.sh scripts/test-install.sh
scripts/test-install.sh
```

Expected: `install.sh checks passed`.

- [ ] **Step 6: Smoke test real local install into a temp Applications folder**

Run:

```bash
tmpdir="$(mktemp -d)"
./install.sh --destination "$tmpdir/Applications"
test -x "$tmpdir/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
codesign --verify "$tmpdir/Applications/TimeZoner.app"
rm -rf "$tmpdir"
```

Expected: commands exit 0.

---

### Task 3: Add Homebrew Formula

**Files:**
- Create: `Formula/timezoner.rb`
- Modify: `README.md`

- [ ] **Step 1: Compute the current stable tarball checksum**

Run:

```bash
tmpfile="$(mktemp)"
curl -L "https://github.com/nembal/Timezoner/archive/refs/tags/v0.2.0.tar.gz" -o "$tmpfile"
shasum -a 256 "$tmpfile"
rm -f "$tmpfile"
```

Expected: one SHA256 value for the formula `sha256` line.

- [ ] **Step 2: Create `Formula/timezoner.rb`**

Create the formula using the verified v0.2.0 SHA256:

```ruby
class Timezoner < Formula
  desc "Lightweight macOS floating panel for instant timezone conversion"
  homepage "https://github.com/nembal/Timezoner"
  url "https://github.com/nembal/Timezoner/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "b2ee6fe0b0f87eae1fa036f44f46d820f5b9f123ff1aaab614714609869f92ce"
  license "MIT"
  head "https://github.com/nembal/Timezoner.git", branch: "main"

  depends_on :macos

  def install
    if Utils.safe_popen_read("xcode-select", "-p").include?("/Library/Developer/CommandLineTools")
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

    (bin/"timezoner").write <<~SH
      #!/bin/bash
      open "#{app_bundle}"
    SH
    chmod 0755, bin/"timezoner"

    (bin/"timezoner-install-app").write <<~SH
      #!/bin/bash
      set -euo pipefail
      destination="${1:-$HOME/Applications}"
      mkdir -p "$destination"
      rm -rf "$destination/TimeZoner.app"
      cp -R "#{app_bundle}" "$destination/TimeZoner.app"
      codesign --force --sign - "$destination/TimeZoner.app" >/dev/null
      echo "Installed TimeZoner.app to $destination/TimeZoner.app"
    SH
    chmod 0755, bin/"timezoner-install-app"
  end

  def caveats
    <<~EOS
      TimeZoner was built locally and ad-hoc signed on this Mac.

      Open it with:
        timezoner

      To copy the app bundle into ~/Applications:
        timezoner-install-app

      To install into /Applications:
        timezoner-install-app /Applications
    EOS
  end

  test do
    assert_predicate prefix/"TimeZoner.app/Contents/MacOS/TimeZoner", :executable?
    system "codesign", "--verify", prefix/"TimeZoner.app"
  end
end
```

- [ ] **Step 3: Run formula style and audit**

Run:

```bash
brew style Formula/timezoner.rb
brew audit --formula Formula/timezoner.rb
```

Expected: both commands exit 0, or only warn about tap naming because the formula lives inside the app repo instead of a dedicated `homebrew-timezoner` tap.

- [ ] **Step 4: Smoke test the formula locally**

Run:

```bash
cleanup() { brew uninstall timezoner >/dev/null 2>&1 || true; }
trap cleanup EXIT
brew install --build-from-source ./Formula/timezoner.rb
timezoner-install-app "$(mktemp -d)/Applications"
brew test timezoner
brew uninstall timezoner
brew install --HEAD --build-from-source ./Formula/timezoner.rb
brew test timezoner
brew uninstall timezoner
```

Expected: stable formula builds, helper copies `TimeZoner.app`, formula test passes, uninstall succeeds, `--HEAD` formula builds current source, formula test passes, uninstall succeeds.

---

### Task 4: Rename DMG Path To Manual DMG Install

**Files:**
- Modify: `README.md`
- Modify: `scripts/dmg-readme.txt`
- Modify: `scripts/create-dmg.sh`

- [ ] **Step 1: Update README install hierarchy**

Change the Download/Install section to this order:

```markdown
## Install

### Recommended: Homebrew source build

```bash
brew tap nembal/timezoner https://github.com/nembal/Timezoner
brew install timezoner
timezoner-install-app
timezoner
```

This builds TimeZoner locally on your Mac, ad-hoc signs the local app bundle, and avoids making an unnotarized downloaded binary the primary install path.

### Source checkout

```bash
git clone https://github.com/nembal/Timezoner.git
cd Timezoner
./install.sh --open
```

### Manual DMG install

The GitHub release DMG remains available for people who prefer drag-and-drop installs. Because it is ad-hoc signed but not Apple-notarized, macOS may require a right-click Open or Privacy & Security override on first launch.
```

- [ ] **Step 2: Update `scripts/dmg-readme.txt`**

Replace its heading with:

```text
Manual DMG Install
==================
```

Replace the top explanation with:

```text
Recommended install for most users:

    brew tap nembal/timezoner https://github.com/nembal/Timezoner
    brew install timezoner
    timezoner-install-app

This DMG is a manual fallback. It is ad-hoc signed but not Apple-notarized,
so macOS may ask you to confirm that you trust it on first launch.
```

Keep the `xattr -cr` command only under a clearly labeled fallback section named `If macOS still blocks launch`.

- [ ] **Step 3: Update `scripts/create-dmg.sh` output**

Change the final install message to:

```bash
echo "Created Manual DMG ${DMG_NAME}.dmg ($(du -h "${DMG_NAME}.dmg" | cut -f1))"
echo ""
echo "Primary install path: Homebrew source build or ./install.sh"
echo "Manual DMG fallback: open the DMG and drag TimeZoner to Applications."
```

- [ ] **Step 4: Verify docs mention the new hierarchy**

Run:

```bash
rg -n "Manual DMG|Homebrew source build|xattr|right-click" README.md scripts/dmg-readme.txt scripts/create-dmg.sh
```

Expected: `Manual DMG` appears in README and DMG README; `xattr` appears only as fallback wording, not as the first install step.

---

### Task 5: Finish Native App Deep Link Support

**Files:**
- Modify: `app/Info.plist`
- Create: `app/Sources/Utilities/TimeZonerDeepLink.swift`
- Modify: `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Sources/Views/ContentView.swift`
- Create: `app/Tests/TimeZonerDeepLinkTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

- [ ] **Step 1: Write failing deep-link parser tests**

Create `app/Tests/TimeZonerDeepLinkTests.swift`:

```swift
import Foundation
import TimeZonerLib

func runTimeZonerDeepLinkTests() {
    print("Running TimeZonerDeepLinkTests...")

    if case .open? = TimeZonerDeepLink.parse(URL(string: "timezoner://open")!) {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL deep link open parse")
    }

    if case .setTime(let hour, let minute, let zoneID, let label)? = TimeZonerDeepLink.parse(URL(string: "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF")!) {
        expectEqualInt(hour, 15, "deep link set hour")
        expectEqualInt(minute, 30, "deep link set minute")
        expectEqualString(zoneID, "America/Los_Angeles", "deep link set zone")
        expectEqualString(label ?? "", "SF", "deep link set label")
    } else {
        testsFailed += 4
        print("  FAIL deep link set parse")
    }

    if TimeZonerDeepLink.parse(URL(string: "timezoner://set?hour=99&minute=0&zone=America%2FLos_Angeles")!) == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL deep link invalid hour rejected")
    }

    if TimeZonerDeepLink.parse(URL(string: "https://example.com/set?hour=15&minute=0&zone=UTC")!) == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL deep link invalid scheme rejected")
    }
}
```

If `expectEqualString` does not exist, add this helper to `app/Tests/TimeZonerTests.swift` near the other helpers:

```swift
func expectEqualString(_ a: String, _ b: String, _ label: String, line: Int = #line) {
    if a == b {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(b), got \(a)")
    }
}
```

- [ ] **Step 2: Register the new test runner**

Add `runTimeZonerDeepLinkTests()` to `app/Tests/TimeZonerTests.swift` after `runSettingsStoreTests()`.

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
cd app && swift run TimeZonerTests
```

Expected: FAIL because `TimeZonerDeepLink` is not defined.

- [ ] **Step 4: Implement `TimeZonerDeepLink`**

Create `app/Sources/Utilities/TimeZonerDeepLink.swift`:

```swift
import Foundation

public enum TimeZonerDeepLink: Equatable {
    case open
    case setTime(hour: Int, minute: Int, zoneID: String, label: String?)

    public static func parse(_ url: URL) -> TimeZonerDeepLink? {
        guard url.scheme?.lowercased() == "timezoner" else { return nil }

        let host = url.host?.lowercased()
        if host == nil || host == "" || host == "open" {
            return .open
        }

        guard host == "set",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        guard let hourString = value("hour"),
              let minuteString = value("minute"),
              let zoneID = value("zone"),
              let hour = Int(hourString),
              let minute = Int(minuteString),
              (0...23).contains(hour),
              (0...59).contains(minute),
              TimeZone(identifier: zoneID) != nil else {
            return nil
        }

        return .setTime(hour: hour, minute: minute, zoneID: zoneID, label: value("label"))
    }
}

extension Notification.Name {
    public static let timeZonerDeepLink = Notification.Name("timeZonerDeepLink")
}
```

- [ ] **Step 5: Register URL scheme in `app/Info.plist`**

Add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.timezoner.app.url</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>timezoner</string>
    </array>
  </dict>
</array>
```

- [ ] **Step 6: Handle URLs in `TimeZonerApp.swift`**

Add this method to `AppDelegate`:

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        guard let command = TimeZonerDeepLink.parse(url) else { continue }
        showPanel()
        NotificationCenter.default.post(name: .timeZonerDeepLink, object: command)
    }
}
```

- [ ] **Step 7: Apply deep-link commands in `ContentView.swift`**

Add an `.onReceive` block:

```swift
.onReceive(NotificationCenter.default.publisher(for: .timeZonerDeepLink)) { notification in
    guard let command = notification.object as? TimeZonerDeepLink else { return }
    switch command {
    case .open:
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    case .setTime(let hour, let minute, let zoneID, let label):
        guard let zone = TimeZone(identifier: zoneID) else { return }
        if !zoneStore.zones.contains(where: { $0.timeZoneId == zoneID }) {
            zoneStore.add(label: label ?? zoneID, timezoneId: zoneID)
        }
        timeState.setTime(hour: hour, minute: minute, in: zone)
        highlightedZoneIds = Set(zoneStore.zones.filter { $0.timeZoneId == zoneID }.map(\.id))
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    }
}
```

- [ ] **Step 8: Run Swift tests**

Run:

```bash
cd app && swift run TimeZonerTests
```

Expected: all tests pass, now including `TimeZonerDeepLinkTests`.

- [ ] **Step 9: Smoke test LaunchServices URL registration**

Run after building the app bundle:

```bash
./build.sh
open "app/TimeZoner.app"
open "timezoner://open"
open "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF"
```

Expected: TimeZoner opens or focuses without a LaunchServices "no application" error. If the current session cannot automate the visible UI assertion, record that limitation and keep parser tests plus successful `open` commands as the automated gate.

---

### Task 6: Finish Raycast Parser, Zone Persistence, And App Open

**Files:**
- Modify: `raycast/src/types.ts`
- Modify: `raycast/src/parser.ts`
- Create: `raycast/src/zones.ts`
- Create: `raycast/src/timezoner-url.ts`
- Modify: `raycast/src/convert-time.tsx`
- Modify: `raycast/src/world-clock.tsx`
- Modify: `raycast/__tests__/parser.test.ts`
- Create: `raycast/__tests__/zones.test.ts`
- Create: `raycast/__tests__/timezoner-url.test.ts`

- [ ] **Step 1: Extend parser tests first**

Add these tests to `raycast/__tests__/parser.test.ts`:

```ts
describe("zone commands", () => {
  it("parses +Tokyo", () => {
    expect(parseQuery("+Tokyo")).toEqual({
      kind: "addZone",
      label: "Tokyo",
      timezone: "Asia/Tokyo",
    });
  });

  it("parses add Hong Kong", () => {
    expect(parseQuery("add Hong Kong")).toEqual({
      kind: "addZone",
      label: "Hong Kong",
      timezone: "Asia/Hong_Kong",
    });
  });

  it("parses -SF", () => {
    expect(parseQuery("-SF")).toEqual({
      kind: "removeZone",
      label: "SF",
    });
  });

  it("parses remove Europe", () => {
    expect(parseQuery("remove Europe")).toEqual({
      kind: "removeZone",
      label: "Europe",
    });
  });
});
```

Update existing conversion assertions to include `kind: "conversion"`.

- [ ] **Step 2: Add URL tests**

Create `raycast/__tests__/timezoner-url.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildTimeZonerURL } from "../src/timezoner-url";

describe("buildTimeZonerURL", () => {
  it("returns open URL without a parsed conversion", () => {
    expect(buildTimeZonerURL(undefined)).toBe("timezoner://open");
  });

  it("encodes conversion details", () => {
    const url = buildTimeZonerURL({
      kind: "conversion",
      hour: 15,
      minute: 30,
      sourceTimezone: "America/Los_Angeles",
      sourceLabel: "sf",
    });
    expect(url).toBe("timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=sf");
  });
});
```

- [ ] **Step 3: Add zone helper tests**

Create `raycast/__tests__/zones.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { addZone, removeZone } from "../src/zones";

describe("zone helpers", () => {
  it("adds a zone without duplicating timezone IDs", () => {
    const zones = addZone([{ label: "SF", timezone: "America/Los_Angeles" }], {
      label: "San Francisco",
      timezone: "America/Los_Angeles",
    });
    expect(zones).toEqual([{ label: "San Francisco", timezone: "America/Los_Angeles" }]);
  });

  it("removes by label or timezone", () => {
    const zones = removeZone(
      [
        { label: "SF", timezone: "America/Los_Angeles" },
        { label: "Bangkok", timezone: "Asia/Bangkok" },
      ],
      "sf",
    );
    expect(zones).toEqual([{ label: "Bangkok", timezone: "Asia/Bangkok" }]);
  });
});
```

- [ ] **Step 4: Run tests to verify failures**

Run:

```bash
cd raycast && npm test
```

Expected: FAIL because parser kinds, `zones.ts`, and `timezoner-url.ts` are not implemented.

- [ ] **Step 5: Update `raycast/src/types.ts`**

Replace `ParsedQuery` with:

```ts
export type ParsedQuery = ParsedConversionQuery | ParsedAddZoneCommand | ParsedRemoveZoneCommand;

export interface ParsedConversionQuery {
  kind: "conversion";
  hour: number;
  minute: number;
  sourceTimezone: string;
  sourceLabel: string;
  targetTimezone?: string;
  targetLabel?: string;
}

export interface ParsedAddZoneCommand {
  kind: "addZone";
  label: string;
  timezone: string;
}

export interface ParsedRemoveZoneCommand {
  kind: "removeZone";
  label: string;
}
```

- [ ] **Step 6: Update `raycast/src/parser.ts`**

Add command parsing before conversion parsing:

```ts
function parseCommand(input: string): ParsedQuery | undefined {
  const trimmed = input.trim();
  const lower = trimmed.toLowerCase();

  if (trimmed.startsWith("+")) {
    const label = trimmed.slice(1).trim();
    const timezone = resolveTimezone(label);
    return label && timezone ? { kind: "addZone", label, timezone } : undefined;
  }

  if (trimmed.startsWith("-")) {
    const label = trimmed.slice(1).trim();
    return label ? { kind: "removeZone", label } : undefined;
  }

  if (lower.startsWith("add ")) {
    const label = trimmed.slice(4).trim();
    const timezone = resolveTimezone(label);
    return label && timezone ? { kind: "addZone", label, timezone } : undefined;
  }

  if (lower.startsWith("remove ")) {
    const label = trimmed.slice(7).trim();
    return label ? { kind: "removeZone", label } : undefined;
  }

  return undefined;
}
```

Every conversion return object must include `kind: "conversion"`.

At the start of `parseQuery`, add:

```ts
const command = parseCommand(trimmed);
if (command) return command;
```

- [ ] **Step 7: Create `raycast/src/zones.ts`**

```ts
import { LocalStorage } from "@raycast/api";
import { resolveZones } from "./aliases";
import type { ZoneInfo } from "./types";

const STORAGE_KEY = "timezoner.zones";

export function addZone(zones: ZoneInfo[], zone: ZoneInfo): ZoneInfo[] {
  return [...zones.filter((z) => z.timezone !== zone.timezone), zone];
}

export function removeZone(zones: ZoneInfo[], labelOrTimezone: string): ZoneInfo[] {
  const normalized = labelOrTimezone.trim().toLowerCase();
  return zones.filter(
    (z) => z.label.trim().toLowerCase() !== normalized && z.timezone.trim().toLowerCase() !== normalized,
  );
}

export async function loadZones(defaultZones: string): Promise<ZoneInfo[]> {
  const stored = await LocalStorage.getItem<string>(STORAGE_KEY);
  if (stored) {
    try {
      const parsed = JSON.parse(stored) as ZoneInfo[];
      if (Array.isArray(parsed)) return parsed;
    } catch {
      await LocalStorage.removeItem(STORAGE_KEY);
    }
  }
  return resolveZones(defaultZones);
}

export async function saveZones(zones: ZoneInfo[]): Promise<void> {
  await LocalStorage.setItem(STORAGE_KEY, JSON.stringify(zones));
}
```

- [ ] **Step 8: Create `raycast/src/timezoner-url.ts`**

```ts
import type { ParsedConversionQuery } from "./types";

export function buildTimeZonerURL(parsed: ParsedConversionQuery | undefined): string {
  if (!parsed) return "timezoner://open";

  const params = new URLSearchParams({
    hour: String(parsed.hour),
    minute: String(parsed.minute),
    zone: parsed.sourceTimezone,
    label: parsed.sourceLabel,
  });

  return `timezoner://set?${params.toString()}`;
}
```

- [ ] **Step 9: Update Raycast commands**

In `convert-time.tsx`, use `useEffect` to load zones with `loadZones(prefs.defaultZones)`, render add/remove command list items when `parsed.kind` is `addZone` or `removeZone`, call `saveZones`, and use `buildTimeZonerURL(parsed.kind === "conversion" ? parsed : undefined)` for `Action.Open`.

In `world-clock.tsx`, load zones with the same `loadZones(prefs.defaultZones)` helper so add/remove commands affect both Raycast commands.

- [ ] **Step 10: Verify Raycast**

Run:

```bash
cd raycast
npm test
npm run lint
npm run build
```

Expected: tests pass, lint passes, and `ray build` completes.

---

### Task 7: Final Verification And Release Notes

**Files:**
- Modify: `README.md`
- Optional modify only if commands prove it stale: `CLAUDE.md`

- [ ] **Step 1: Run full local verification**

Run:

```bash
scripts/test-install.sh
cd app && swift run TimeZonerTests
cd ../raycast && npm test && npm run lint && npm run build
cd ..
brew audit --formula Formula/timezoner.rb
./build.sh
open "app/TimeZoner.app"
open "timezoner://open"
open "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF"
```

Expected: all commands pass. If `brew audit` warns only about personal tap naming, record the exact warning in the final report and keep the formula.

- [ ] **Step 2: Verify source-built install command**

Run:

```bash
tmpdir="$(mktemp -d)"
./install.sh --destination "$tmpdir/Applications"
test -x "$tmpdir/Applications/TimeZoner.app/Contents/MacOS/TimeZoner"
codesign --verify "$tmpdir/Applications/TimeZoner.app"
rm -rf "$tmpdir"
```

Expected: app installs into the temp Applications directory and verifies.

- [ ] **Step 3: Verify Homebrew formula install**

Run:

```bash
cleanup() { brew uninstall timezoner >/dev/null 2>&1 || true; }
trap cleanup EXIT
brew install --build-from-source ./Formula/timezoner.rb
timezoner-install-app "$(mktemp -d)/Applications"
brew test timezoner
brew uninstall timezoner
brew install --HEAD --build-from-source ./Formula/timezoner.rb
brew test timezoner
brew uninstall timezoner
```

Expected: stable and `--HEAD` formula paths build, test, and uninstall cleanly.

- [ ] **Step 4: Inspect changed files**

Run:

```bash
git status --short
git diff --stat
git diff -- README.md scripts/dmg-readme.txt scripts/create-dmg.sh
```

Expected: changed files match this plan. README shows Homebrew/source install first and Manual DMG as fallback.

- [ ] **Step 5: Commit**

Run:

```bash
git add install.sh scripts/build.sh scripts/test-install.sh Formula/timezoner.rb README.md scripts/dmg-readme.txt scripts/create-dmg.sh app/Info.plist app/Sources app/Tests raycast/src raycast/__tests__ raycast/package.json raycast/package-lock.json
git commit -m "feat: add source installs and complete Raycast"
```

Expected: one feature commit on `codex/install-raycast-distribution`.

## Self-Review

- Spec coverage: Homebrew source install is Task 3, `install.sh` and CLT build reliability are Task 2, Manual DMG rename is Task 4, Raycast completion is Task 6, native app URL support for Raycast is Task 5, verification is Task 7, and the fresh reviewer subagent checkpoint is recorded in Requirements and Current Evidence.
- Placeholder scan: no replacement tokens remain. The v0.2.0 tarball SHA256 is `b2ee6fe0b0f87eae1fa036f44f46d820f5b9f123ff1aaab614714609869f92ce`.
- Type consistency: Raycast parser returns `ParsedQuery`; conversion consumers narrow to `kind: "conversion"`; app deep link parser returns `TimeZonerDeepLink`.
- Risk callout: the stable formula points at `v0.3.0`; use `--HEAD` only when testing current `main` ahead of the next tag.
