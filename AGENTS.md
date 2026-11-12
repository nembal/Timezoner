# TimeZoner

A lightweight macOS floating-panel app for instant timezone conversion. Built for people who live in one timezone and work across several others.

**Repo:** https://github.com/nembal/Timezoner

## Quick Start

```bash
./install.sh --open # builds, signs, installs to ~/Applications, and launches
./build.sh          # builds TimeZoner.app (in app/)
open app/TimeZoner.app  # launches the app
```

Build requires the SPM fix wrapper (auto-applied by build script) due to a CLT toolchain mismatch. If you have Xcode installed, `cd app && swift build` works. Tests:

```
cd app && swift run TimeZonerTests
```

## Vision

Replace the "google what time is it in SF" workflow with a single floating panel that's always one keystroke away. Type natural language, get instant results across all your zones. No accounts, no network, no friction.

## Architecture

```
┌──────────────────────────────────────────────┐
│  ─── drag pill ───                           │
│  [chat field]                    [Now]  [⚙]  │
│                                              │
│  [BKK] →+14h→ [SF] →+3h→ [NY] →+5h→ [LDN]  │
│   drag pill    drag pill   drag pill         │
│  [collapsible timezone map]                  │
└──────────────────────────────────────────────┘
     ▲
     │ NSStatusItem (clock icon in menu bar)

TimeState (@Observable)  ← single source of truth (one Date)
ZoneStore (@Observable)  ← user's zone list (UserDefaults)
InputParser              ← regex-based forgiving NL parser
TimezoneAliases          ← 376-entry lookup table
TimeFormatter            ← cached DateFormatter instances
TimeZonerDeepLink        ← timezoner://open and timezoner://set?... parser
```

**Data flow:** Chat, card edits, deep links, and timed calendar event selection go through `ReferenceMomentController`, which owns the shared `TimeState`. All cards and the map recompute from the same absolute reference date. All-day calendar details do not change that date.

**Calendar source branch:** `CalendarPanelCoordinator` owns the native panels, `CalendarPanelPairController` handles normal pairing and resizing, and the workspace models own expansion/restoration. `ZoneCardCollection` is shared by the horizontal row and `TimeZonerRailView`. EventKit access stays in `EventKitCalendarProvider`; event presentation stays in memory. Calendar Companion is unreleased; source build metadata does not establish a published release. See `docs/RELEASE_READINESS.md` for current checks and pending native acceptance.

**Integration flow:** Raycast builds `timezoner://` URLs → AppDelegate parses them → `DeepLinkRouter` queues/dispatches the command → `ContentView` adds a missing zone if needed, sets `TimeState`, and highlights the target card.

## Project Structure

```
app/                              # macOS SwiftUI app
  Sources/
    App/
      TimeZonerApp.swift          # @main, AppDelegate, NSStatusItem
      FloatingPanel.swift         # Borderless NSPanel
    Models/
      TimeState.swift             # @Observable — the reference moment
      ZoneInfo.swift              # Single zone (id, label, IANA timezone id)
    Stores/
      ZoneStore.swift             # @Observable — zone list, UserDefaults
      SettingsStore.swift         # @Observable — user prefs (appearance, hotkey, login)
    Data/
      TimezoneAliases.swift       # Auto-generated from shared JSON
      GeoJSONTypes.swift          # Bundled timezone boundary loader
      CityCoordinates.swift       # City dot coordinates for the map
    Parser/
      InputParser.swift           # Forgiving time + zone parser
    Views/
      ContentView.swift           # Main layout
      ChatField.swift             # NL input
      ZoneCard.swift              # Editable time card
      ZoneCardRow.swift           # Horizontal card row
      DragHandle.swift            # Window drag
      SettingsPopover.swift       # ⚙ popover (appearance, hotkey, login, help)
      HotkeyRecorderField.swift   # Keystroke capture NSView
      TimezoneMapView.swift       # Collapsible hoverable/clickable timezone map
      Theme.swift                 # Adaptive light/dark palette
    Utilities/
      TimeFormatter.swift         # Cached formatters, thread-safe
      HotkeyManager.swift         # Carbon RegisterEventHotKey wrapper
      LaunchAtLogin.swift         # SMAppService helper
      MapColorLogic.swift         # Timezone map visual state
      MapProjection.swift         # Equirectangular projection + paths
      TimeZonerDeepLink.swift     # URL scheme parser + router
    Resources/
      timezone-boundaries.json    # Bundled timezone GeoJSON
  Tests/
    TimeZonerTests.swift          # Test runner (@main)
    TimezoneAliasTests.swift
    TimeStateTests.swift
    ZoneStoreTests.swift
    InputParserTests.swift
    TimeFormatterTests.swift
    TimezoneMapTests.swift
    SettingsStoreTests.swift
    TimeZonerDeepLinkTests.swift
  Package.swift
  Info.plist
  fix-spm.sh
shared/
  timezone-aliases.json           # 376 aliases — single source of truth
raycast/                          # Raycast extension (source-installed for now)
  src/
    convert-time.tsx              # single `tz` TimeZoner command
    map-preview.ts                # SVG card and static timezone map rendering
    parser.ts                     # TypeScript parser port
    zones.ts                      # Raycast LocalStorage zone persistence
    timezoner-url.ts              # timezoner:// URL builder
    data/timezones.ts             # Generated alias map
    data/timezone-boundaries.json # Bundled timezone boundary data for Raycast map
    ../ATTRIBUTION.md             # Raycast map data provenance note
scripts/
  build.sh                        # App build
  create-dmg.sh                   # DMG packaging
  test-install.sh                 # Install/formula packaging checks
  sync-aliases.sh                 # Generate Swift from shared JSON
  generate-swift-aliases.py       # Python codegen
Formula/
  timezoner.rb                    # Stable Homebrew source-build formula, with HEAD fallback
docs/
  prd/                            # Product requirements
  RELEASE_READINESS.md            # Remaining release/distribution checklist
install.sh                        # Source checkout installer
```

**Three SPM targets** (defined in `app/Package.swift`):
- `TimeZonerLib` (library) — all code except App/
- `TimeZoner` (executable) — App/ files, depends on TimeZonerLib
- `TimeZonerTests` (executable) — custom test runner (no XCTest required)

## Tech Stack

- **SwiftUI** + **AppKit** (borderless NSPanel)
- **Swift Package Manager** — no Xcode project
- **macOS 14+** (Observation framework)
- **Zero dependencies, zero network**

## Key Design Decisions

- **`@Observable` not `ObservableObject`** — macOS 14+ Observation framework. Views use `@State`/`@Bindable`.
- **Borderless NSPanel** — no title bar, no traffic lights. Custom drag handle with manual mouse tracking (avoids macOS tiling gestures).
- **Menu bar hugging** — square top corners when docked to menu bar, rounded when floating.
- **Executable test target** — standalone test runner, no XCTest/Xcode needed.
- **376 bundled aliases** — cities, abbreviations, airport codes, countries, timezone abbrevs.
- **Single source of truth** — `TimeState.referenceDate` is one absolute `Date`.
- **Reference moment controller** — conversion inputs and timed event selection use `ReferenceMomentController`; it coordinates selected-event context and map restoration alongside the shared `TimeState`.
- **Cached DateFormatters** — thread-safe FormatterCache with NSLock.
- **Adaptive dark mode** — `NSColor(dynamicProvider:)` for all theme colors.
- **Equal horizontal cards** — `CalendarPanelMetrics.normalCardWidth` is 200 points including padding; `normalCardGap` is 36 points and outer insets are 20 points. Four cities prefer a 948-point panel and five prefer 1184 points. Normal panel resizing caps width at the visible display and clamps horizontal placement; `ZoneCardRow` scrolls fixed-width cards on narrow displays. No ellipsis menu: click the time to edit, drag the top pill to reorder, and show the remove button only on hover as a top-right overlay. Retain accessibility actions. Do not add an action row or width-driven header measurement. The calendar's vertical rail stays flexible.
- **Global hotkey via Carbon** — `RegisterEventHotKey` keeps zero-dep rule and intercepts system-wide. Default `⌘⌥T`.
- **Settings popover, not a window** — gear button opens a SwiftUI popover with appearance override (System/Light/Dark), launch-at-login, hotkey recorder, and input-format help. `⌘,` also opens it.
- **Source-built distribution first** — Homebrew and `install.sh` build locally, copy the SwiftPM resource bundle, and ad-hoc sign the result. This avoids requiring an Apple Developer Program account for the primary install path.
- **Homebrew formula builds from tagged source by default** — `brew install timezoner` uses the latest release tarball and builds locally; current Homebrew may require `brew trust --formula nembal/timezoner/timezoner` for this third-party tap; `brew install --HEAD timezoner` remains available for current `main`.
- **Deep links are the app integration contract** — Raycast opens `timezoner://open` or `timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF`; the app queues links safely during cold start.
- **Raycast zones are standalone** — Raycast persists add/edit/remove zone commands in Raycast LocalStorage and does not sync zone lists with the macOS app.
- **Raycast is one command** — the `tz` TimeZoner command combines live world-clock cards, natural-language conversion, same-screen card time editing through the search bar, one-click edit retargeting between cards, and a static map preview.
- **Raycast map attribution** — keep `raycast/ATTRIBUTION.md` with the extension when copying it into the Raycast Store repository; the bundled map boundary database carries ODbL/OpenStreetMap attribution.

## Shared Data

The 376-timezone alias table is shared between the macOS app and the Raycast extension:

- **Source of truth:** `shared/timezone-aliases.json` — JSON array of `{ alias, iana_id, category }` objects
- **Generation:** `scripts/sync-aliases.sh` regenerates both `app/Sources/Data/TimezoneAliases.swift` and `raycast/src/data/timezones.ts` from the JSON
- **Adding an alias:** Edit `shared/timezone-aliases.json`, then run `bash scripts/sync-aliases.sh`

## Chat Parser Input Formats

```
11:30am SF        3pm bangkok       15:00 BKK
1130 am PT        noon NYC          midnight CET
1130am BKK in SF  +Tokyo            -NYC
add Hong Kong     remove Europe     12 (bare → active zone)
```

## Branches

- `main` — stable, release-ready

## Future Roadmap

- Raycast Store review/merge for https://github.com/raycast/extensions/pull/29168
- Flight tracking (AviationStack free tier)
- macOS widget
- Default-cities picker in Settings
