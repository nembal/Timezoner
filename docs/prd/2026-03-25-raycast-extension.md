# PRD: Raycast Extension

## Overview

A Raycast extension that brings TimeZoner's natural language timezone conversion directly into Raycast's search bar. Type `tz 3pm SF` and instantly see the converted time across all your zones without opening the full app.

## Problem

Even with TimeZoner.app, you still need to click the menu bar icon or find the floating panel. For quick one-off conversions ("what's 3pm SF in Bangkok?"), the fastest path is typing directly into Raycast — the tool many power users already have open constantly.

## Competitive Landscape

The Raycast store has ~6 timezone-related extensions (~16K installs combined). **None** support:
- Natural language time input (`3pm SF`, `1130am BKK`)
- City abbreviations or airport codes (SF, NYC, BKK, SFO, JFK)
- Cross-zone queries (`1130am BKK in SF`)
- Forgiving input parsing (no colon, short am/pm, etc.)

Every existing extension requires picking from a dropdown of 400+ IANA identifiers. This would be the first to support freeform natural language timezone conversion.

## Goal

Type a timezone query in Raycast, see instant results. Copy with one keystroke. Optionally open TimeZoner.app for the full card view.

## User Stories

1. **As a user**, I type `tz 3pm SF` and instantly see that time in all my saved zones.
2. **As a user**, I type `tz 1130am BKK in SF` and see the conversion highlighted.
3. **As a user**, I press Enter on a result to copy the time to my clipboard.
4. **As a user**, I press Cmd+O on a result to open TimeZoner.app with that time set.
5. **As a user**, I type `tz +Tokyo` to add Tokyo to my zone list (synced with the app).
6. **As a user**, I can configure my default zones in Raycast preferences.

## Design

### Command: `Convert Time`

Keyword trigger: `tz` (configurable)

```
┌─────────────────────────────────────────┐
│ tz 3pm SF                               │
├─────────────────────────────────────────┤
│ 🟠 SF          3:00 pm   Mon, Mar 24   │  ← source (highlighted)
│    Bangkok      5:00 am   Tue, Mar 25   │
│    New York     6:00 pm   Mon, Mar 24   │
│    London      11:00 pm   Mon, Mar 24   │
├─────────────────────────────────────────┤
│ ↩ Copy  ⌘O Open in TimeZoner  ⌘C Copy All │
└─────────────────────────────────────────┘
```

### Command: `World Clock`

Keyword trigger: `wc` (configurable)

Shows current time in all saved zones. Same list format, no input needed.

### Behavior

- **As you type**, results update live (debounced)
- **Enter**: copies the focused zone's time (e.g., "3:00 PM PST")
- **Cmd+Shift+C**: copies all zones as a formatted block
- **Cmd+O**: opens TimeZoner.app (if installed)
- **Empty query**: shows current time across all zones (like World Clock)

### Preferences

- **Default zones**: comma-separated list (e.g., "Bangkok, SF, New York, London")
- **Time format**: 12h / 24h
- **Copy format**: "3:00 PM PST" / "15:00 PST" / "3:00 PM (San Francisco)"

## Technical Approach

### Monorepo Structure

```
TimeZoner/
├── app/                          # macOS SwiftUI app (existing)
│   ├── Sources/
│   ├── Tests/
│   ├── Package.swift
│   ├── build.sh
│   └── Info.plist
├── raycast/                      # Raycast extension (new)
│   ├── src/
│   │   ├── convert-time.tsx      # Main command
│   │   ├── world-clock.tsx       # Current time command
│   │   ├── data/
│   │   │   └── timezones.ts      # Ported alias table (376 entries)
│   │   ├── parser.ts             # Ported InputParser logic
│   │   └── utils.ts              # Time formatting helpers
│   ├── package.json
│   ├── tsconfig.json
│   └── assets/
│       └── icon.png              # Extension icon (512x512)
├── shared/                       # Shared data (source of truth)
│   └── timezone-aliases.json     # 376 aliases in JSON format
├── scripts/
│   ├── build.sh                  # App build
│   ├── create-dmg.sh             # App packaging
│   └── sync-aliases.sh           # Generate .ts and .swift from shared JSON
├── docs/
├── README.md
├── CLAUDE.md
└── LICENSE
```

### Shared Data Strategy

The 376-timezone alias table is the core asset shared between the Swift app and the Raycast extension. To keep them in sync:

1. **Source of truth**: `shared/timezone-aliases.json` — a JSON array of `{ alias, iana_id }` pairs
2. **Swift generation**: `scripts/sync-aliases.sh` generates `Sources/Data/TimezoneAliases.swift` from the JSON
3. **TypeScript import**: `raycast/src/data/timezones.ts` imports the JSON directly

This means adding a new alias is a single edit to one JSON file.

### Parser Port

The InputParser logic ports from Swift regex to TypeScript regex. The patterns are identical — just syntax differences:

```typescript
// Swift: #"^(\d{1,2}):(\d{2})\s*(a\.m\.|p\.m\.|am|pm|a|p)?\s+(.+)$"#
// TypeScript:
const PATTERN_A = /^(\d{1,2}):(\d{2})\s*(a\.m\.|p\.m\.|am|pm|a|p)?\s+(.+)$/i;
```

The `parseBareTime()` and `resolveTimezone()` functions are straightforward ports.

### Time Conversion

Use JavaScript's `Intl.DateTimeFormat` with timezone option — no external dependencies:

```typescript
const formatter = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/Los_Angeles',
  hour: 'numeric', minute: '2-digit',
  hour12: true,
});
const timeStr = formatter.format(date); // "3:00 PM"
```

### App Communication

1. **Shared UserDefaults**: Both the app and extension can read/write to the same UserDefaults suite (via app group, if both are signed with the same team ID)
2. **URL scheme**: The app registers `timezoner://` — the extension can `open("timezoner://set?time=1500&zone=America/Los_Angeles")`
3. **Fallback**: If the app isn't installed, the extension works standalone with its own zone preferences

## Data Size

| Component | Size |
|-----------|------|
| timezone-aliases.json | ~15KB |
| parser.ts | ~150 lines |
| convert-time.tsx | ~200 lines |
| world-clock.tsx | ~80 lines |
| utils.ts | ~50 lines |
| **Total extension** | ~500 lines, ~20KB |

## Publishing

1. Fork `github.com/raycast/extensions`
2. Add extension under `extensions/timezoner/`
3. Submit PR with README, icon, screenshots
4. Raycast team reviews (3-7 days)
5. Appears in Raycast Store

## Out of Scope (v1)

- Syncing zone list between app and extension (use separate preferences initially)
- Calendar integration
- Meeting time suggestion ("find overlap")
- Relative time queries ("3 hours from now in Tokyo")

## Success Criteria

1. Type `tz 3pm SF` → see results in <100ms
2. All 376 aliases resolve correctly
3. Copy-to-clipboard works for quick pasting into Slack/email
4. Published in Raycast Store within 2 weeks
5. Standalone — works without TimeZoner.app installed

## Open Questions

1. Should the extension auto-detect the user's local timezone for the default "home" zone?
2. Should we support relative queries like "in 3 hours" in v1?
3. Should zone preferences sync with the app via a shared file/defaults, or stay independent?
