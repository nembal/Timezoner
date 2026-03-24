# TimeZoner

A lightweight macOS floating-panel app for instant timezone conversion. Built for people who live in one timezone and work across several others.

## Quick Start

```bash
./build.sh          # builds TimeZoner.app
open TimeZoner.app  # launches the app
```

Build requires the SPM fix wrapper (auto-applied by `build.sh`) due to a CLT toolchain mismatch. Tests run via:

```bash
SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh swift run TimeZonerTests
```

## Vision

Replace the "google what time is it in SF" workflow with a single floating panel that's always one keystroke away. Type natural language ("11:30am BKK", "3p SF", "noon NYC"), get instant results across all your zones. No accounts, no network, no friction.

Future: Raycast extension, menu bar popover mode, flight arrival time conversion, widgets.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  FloatingPanel                   │
│  (NSPanel, always-on-top, .ultraThinMaterial)    │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │  ChatField (natural language input)         │ │
│  │  "11:30am SF, +Tokyo, -NYC..."              │ │
│  └──────────────────────┬──────────────────────┘ │
│                         │ InputParser.parse()     │
│                         ▼                         │
│  ┌──────────────────────────────────────────────┐│
│  │  TimeState (@Observable)                     ││
│  │  Single source of truth: referenceDate       ││
│  │  All inputs update this, all views read it   ││
│  └──────────────────────┬───────────────────────┘│
│                         │                         │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
│  │Bangkok │ │  SF    │ │  NY    │ │ Europe │    │
│  │11:30AM │ │9:30PM  │ │12:30AM │ │ 5:30AM │    │
│  │ZoneCard│ │ZoneCard│ │ZoneCard│ │ZoneCard│    │
│  └────────┘ └────────┘ └────────┘ └────────┘    │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │  TimeScrubber (30-min increments, ±12h)     │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
     ▲
     │ NSStatusItem (clock icon in menu bar)
```

**Data flow:** Every input (chat field, card edit, scrubber drag) updates `TimeState.referenceDate`. Every zone card is a pure function: `referenceDate → formatted time in that zone`. One source of truth, many views.

## Project Structure

```
Sources/
  App/
    TimeZonerApp.swift      # @main, AppDelegate, NSStatusItem
    FloatingPanel.swift     # NSPanel subclass (floating, translucent)
  Models/
    TimeState.swift         # @Observable — the reference moment being converted
    ZoneInfo.swift          # Single zone (id, label, IANA timezone id)
  Stores/
    ZoneStore.swift         # @Observable — user's zone list, persisted to UserDefaults
  Data/
    TimezoneAliases.swift   # 376 entries: cities, abbreviations, airports → IANA ids
  Parser/
    InputParser.swift       # Regex-based forgiving time + zone parser
  Views/
    ContentView.swift       # Main layout wiring ChatField + ZoneCardRow + TimeScrubber
    ChatField.swift         # Top input field with auto-focus and shake-on-error
    ZoneCard.swift          # Editable timezone card (click time to edit inline)
    ZoneCardRow.swift       # Horizontal ScrollView of zone cards
    TimeScrubber.swift      # Draggable horizontal time strip
  Utilities/
    TimeFormatter.swift     # formatTime, formatDate, relativeOffset helpers
Tests/
    TimeZonerTests.swift    # Test runner (@main entry point)
    TimezoneAliasTests.swift
    TimeStateTests.swift
    ZoneStoreTests.swift
    InputParserTests.swift
    TimeFormatterTests.swift
```

**Two SPM targets:**
- `TimeZonerLib` (library) — all code except App/
- `TimeZoner` (executable) — App/ files, depends on TimeZonerLib
- `TimeZonerTests` (executable) — custom test runner (no XCTest/Xcode required)

## Tech Stack

- **SwiftUI** + **AppKit** (NSPanel for floating window)
- **Swift Package Manager** — no Xcode project needed
- **macOS 14+** (Observation framework for `@Observable`)
- **No network, no API keys, no server** — everything is bundled

## Key Design Decisions

- **`@Observable` (not `ObservableObject`)** — Uses the Observation framework (macOS 14+). Views use `@State` and `@Bindable`, not `@StateObject`/`@ObservedObject`.
- **Executable test target** — No Xcode installed, XCTest unavailable. Tests are a standalone executable with a minimal assertion framework.
- **Bundled alias data** — 376 static entries instead of external data files. Covers cities, abbreviations (SF, NYC, BKK), airport codes (SFO, JFK, LHR), country names, timezone abbreviations. No network lookup needed.
- **Single source of truth** — `TimeState.referenceDate` is one absolute `Date`. Timezones are just formatting lenses on that same moment.

## Data Sources Referenced

- **[city-timezones](https://github.com/kevinroberts/city-timezones)** (161 stars) — JSON mapping of 7K cities to IANA timezone IDs. Used as reference for building our curated alias table.
- **[mwgg/Airports](https://github.com/mwgg/Airports)** (725 stars) — 29K airports with IATA codes and timezones. Used as reference for airport code mappings.
- **[Clocker](https://github.com/n0shake/clocker)** (600 stars) — Existing macOS timezone app. Studied for UI patterns (time slider concept). Our UI is modernized and horizontal.
- **Apple `TimeZone` API** — Used as fallback for IANA identifiers and DST handling.

## Chat Parser Input Formats

The parser is intentionally forgiving. All of these work:

```
11:30am PT       11:30 am PT      1130am PT       1130 am PT
1130 a BKK       3 p SF           11:30 a.m. NYC  3pm bangkok
15:00 BKK        noon NYC         midnight CET
+Tokyo           add HK           -SF             remove NYC
```

## Future Roadmap (v2)

- Raycast extension for launch-from-anywhere
- Menu bar popover mode (full UI in menu bar dropdown)
- Flight tracking — type a flight number, see arrival time in your home timezone (AviationStack free tier)
- macOS widget
- Global hotkey for instant activation
