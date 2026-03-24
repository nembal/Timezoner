# TimeZoner

A lightweight macOS floating-panel app for instant timezone conversion. Type natural language, see results across all your zones instantly.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## What it does

Type `3pm SF` and instantly see what time that is in Bangkok, New York, London, or any timezone you've added. Click any card to edit the time directly — all other cards update live as you type.

### Features

- **Natural language input** — `11:30am SF`, `3pm bangkok`, `noon NYC`, `midnight CET`
- **Forgiving parser** — `1130 a BKK`, `3 p sf`, `15:00 london` all work
- **Cross-zone queries** — `1130am BKK in SF` sets the time and highlights both zones
- **Live card editing** — click any time, start typing, everything updates instantly
- **376 timezone aliases** — cities, abbreviations (SF, NYC, HK), airport codes (SFO, JFK, LHR), countries
- **Drag to reorder** — grab the pill on any card to rearrange
- **Dark mode** — adapts to system appearance
- **Menu bar icon** — click to toggle, always one keystroke away
- **Remembers position** — stays where you put it between launches
- **Zero network** — everything is bundled, works offline

### Input formats

```
11:30am SF          3pm bangkok         15:00 BKK
1130 am PT          noon NYC            midnight CET
1130am BKK in SF    +Tokyo              -NYC
add Hong Kong       remove Europe       12 (bare → active zone)
```

## Download

**[Download the latest DMG](https://github.com/nembal/Timezoner/releases/latest)** (Apple Silicon, ~440KB)

1. Open the DMG
2. Drag TimeZoner to Applications
3. First launch: right-click the app → **Open** (required for unsigned apps)

Requires macOS 14+ (Sonoma or later). Apple Silicon only (M1/M2/M3/M4/M5).

## Build from source

```bash
git clone https://github.com/nembal/Timezoner.git
cd Timezoner
chmod +x build.sh
./build.sh
open TimeZoner.app
```

To create a DMG: `./scripts/create-dmg.sh 0.1.0`

If `swift build` fails with a linker error about `PackageDescription`, your Command Line Tools may have a known mismatch. `build.sh` applies a workaround automatically. Installing Xcode resolves this permanently.

## Architecture

```
ContentView
  +-- ChatField          (natural language input)
  +-- ZoneCardRow         (horizontal row of cards)
  |     +-- ZoneCard      (editable time, drag pill, hover controls)
  |     +-- time diff     (+14h, +3h annotations between cards)
  +-- DragHandle          (window positioning)

TimeState (@Observable)   single source of truth — one absolute moment
ZoneStore (@Observable)   user's zone list, persisted to UserDefaults
InputParser               regex-based forgiving time + zone parser
TimezoneAliases           376-entry lookup table (city/airport/abbreviation → IANA)
TimeFormatter             cached DateFormatter instances, thread-safe
```

**Data flow:** Every input (chat, card edit) calls `TimeState.setTime(hour:minute:in:)` which updates the reference date. All cards recompute as pure functions of that date.

## Tech stack

- **SwiftUI** + **AppKit** (NSPanel for borderless floating window)
- **Swift Package Manager** — no Xcode project needed
- **Observation framework** (`@Observable`, macOS 14+)
- No dependencies, no network, no API keys

## License

MIT — see [LICENSE](LICENSE).
