# TimeZoner

A lightweight macOS floating-panel app for instant timezone conversion. Built for people who live in one timezone and work across several others.

**Repo:** https://github.com/nembal/Timezoner

## Quick Start

```bash
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
│  [chat field]                    [Now]  [?]  │
│                                              │
│  [BKK] →+14h→ [SF] →+3h→ [NY] →+5h→ [LDN]  │
│   drag pill    drag pill   drag pill         │
└──────────────────────────────────────────────┘
     ▲
     │ NSStatusItem (clock icon in menu bar)

TimeState (@Observable)  ← single source of truth (one Date)
ZoneStore (@Observable)  ← user's zone list (UserDefaults)
InputParser              ← regex-based forgiving NL parser
TimezoneAliases          ← 376-entry lookup table
TimeFormatter            ← cached DateFormatter instances
```

**Data flow:** Every input (chat, card edit) → `TimeState.setTime()` → all cards recompute as pure functions of that date.

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
    Data/
      TimezoneAliases.swift       # Auto-generated from shared JSON
    Parser/
      InputParser.swift           # Forgiving time + zone parser
    Views/
      ContentView.swift           # Main layout
      ChatField.swift             # NL input
      ZoneCard.swift              # Editable time card
      ZoneCardRow.swift           # Horizontal card row
      DragHandle.swift            # Window drag
      HelpPopover.swift           # Input format examples
      Theme.swift                 # Adaptive light/dark palette
    Utilities/
      TimeFormatter.swift         # Cached formatters, thread-safe
  Tests/
    TimeZonerTests.swift          # Test runner (@main)
    TimezoneAliasTests.swift
    TimeStateTests.swift
    ZoneStoreTests.swift
    InputParserTests.swift
    TimeFormatterTests.swift
  Package.swift
  Info.plist
  fix-spm.sh
shared/
  timezone-aliases.json           # 376 aliases — single source of truth
raycast/                          # Raycast extension (planned)
scripts/
  build.sh                        # App build
  create-dmg.sh                   # DMG packaging
  sync-aliases.sh                 # Generate Swift from shared JSON
  generate-swift-aliases.py       # Python codegen
docs/
  prd/                            # Product requirements
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
- **Cached DateFormatters** — thread-safe FormatterCache with NSLock.
- **Adaptive dark mode** — `NSColor(dynamicProvider:)` for all theme colors.

## Shared Data

The 376-timezone alias table is shared between the macOS app and the Raycast extension:

- **Source of truth:** `shared/timezone-aliases.json` — JSON array of `{ alias, iana_id, category }` objects
- **Swift generation:** `scripts/sync-aliases.sh` regenerates `app/Sources/Data/TimezoneAliases.swift` from the JSON
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
- `feature/timezone-map` — PRD for collapsible world timezone map (upcoming)

## Future Roadmap

- Interactive timezone map (PRD in `docs/prd/`)
- Raycast extension
- Flight tracking (AviationStack free tier)
- macOS widget
- Settings panel (default cities, theme, frosted glass toggle)
- Global hotkey
