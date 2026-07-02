# PRD: Raycast Extension

**Status:** Implemented in source. Raycast Store submission PR is open at https://github.com/raycast/extensions/pull/29168; public availability depends on Raycast review/merge.

## Overview

A Raycast extension that brings TimeZoner's natural language timezone conversion directly into Raycast. Type `tz 3pm in SF` and instantly see that time across saved zone cards, with a static timezone map underneath, without opening the full app.

## Problem

Even with TimeZoner.app, you still need to click the menu bar icon or find the floating panel. For quick one-off conversions ("what's 3pm SF in Bangkok?"), the fastest path is typing directly into Raycast, the tool many power users already have open constantly.

## Competitive Landscape

The Raycast store has ~6 timezone-related extensions (~16K installs combined). **None** support:
- Natural language time input (`3pm SF`, `1130am BKK`)
- City abbreviations or airport codes (SF, NYC, BKK, SFO, JFK)
- Cross-zone queries (`1130am BKK in SF`)
- Forgiving input parsing (no colon, short am/pm, etc.)

Every existing extension requires picking from a dropdown of 400+ IANA identifiers. This would be the first to support freeform natural language timezone conversion.

## Goal

Type a timezone query in Raycast, see instant card results, edit any card's local time in the search bar, copy with one keystroke, and optionally open TimeZoner.app for the native floating panel.

## User Stories

1. **As a user**, I type `tz 3pm in SF` and instantly see that time in all my saved zones.
2. **As a user**, I type `tz 1130am BKK in SF` and see the conversion highlighted.
3. **As a user**, I press Enter on a card to edit that card's time in the search bar.
4. **As a user**, I use the action panel to copy a time or press Cmd+O to open TimeZoner.app with that time set.
5. **As a user**, I type `tz +Tokyo` to add Tokyo to my Raycast zone list.
6. **As a user**, I can configure my default zones in Raycast preferences.

## Design

### Command: `TimeZoner`

Keyword trigger: `tz` (configurable)

```
┌─────────────────────────────────────────┐
│ tz 3pm in SF                            │
├─────────────────────────────────────────┤
│ [SF card] [Bangkok card] [New York card] │
│ [static timezone boundary map]           │
├─────────────────────────────────────────┤
│ ↩ Edit Time  ⌘O Open in TimeZoner        │
└─────────────────────────────────────────┘
```

### Behavior

- **Empty query**: shows current time across saved zones as cards.
- **As you type**, results update live.
- **Enter on a card**: switches the search bar into card-edit mode for that timezone.
- **Selecting another card while editing**: retargets edit mode to that card in one click and updates the visible Raycast status toast.
- **Cmd+Shift+C**: copies all zones as a formatted block
- **Cmd+O**: opens TimeZoner.app (if installed)
- **Add/edit/remove actions**: `+Tokyo`, `add Hong Kong`, `-SF`, `remove Europe`, the Add Zone form, and the Edit Zone form update the Raycast-local zone list
- **Static map preview**: shows bundled timezone boundaries, highlighted saved zones, matching offset regions, exact dots for common city zones, and deterministic offset markers for less common zones.

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
│   └── Info.plist
├── raycast/                      # Raycast extension (source-installed for now)
│   ├── src/
│   │   ├── convert-time.tsx      # Single TimeZoner command
│   │   ├── map-preview.ts        # SVG card and map rendering
│   │   ├── data/
│   │   │   ├── timezones.ts      # Generated alias table (376 entries)
│   │   │   └── timezone-boundaries.json # Bundled map boundaries
│   │   ├── parser.ts             # Ported InputParser logic
│   │   ├── formatter.ts          # Time formatting helpers
│   │   ├── zones.ts              # Raycast LocalStorage zone persistence
│   │   └── timezoner-url.ts      # timezoner:// URL builder
│   ├── package.json
│   ├── tsconfig.json
│   └── assets/
│       └── icon.png              # Extension icon (512x512)
├── shared/                       # Shared data (source of truth)
│   └── timezone-aliases.json     # 376 aliases in JSON format
├── scripts/
│   ├── build.sh                  # App build
│   ├── create-dmg.sh             # App packaging
│   ├── test-install.sh           # Install/formula packaging checks
│   └── sync-aliases.sh           # Generate .ts and .swift from shared JSON
├── Formula/
│   └── timezoner.rb              # Stable Homebrew formula with HEAD fallback
├── docs/
├── README.md
├── CLAUDE.md
├── install.sh
└── LICENSE
```

### Shared Data Strategy

The 376-timezone alias table is the core asset shared between the Swift app and the Raycast extension. To keep them in sync:

1. **Source of truth**: `shared/timezone-aliases.json` — a JSON array of `{ alias, iana_id }` pairs
2. **Swift generation**: `scripts/sync-aliases.sh` generates `app/Sources/Data/TimezoneAliases.swift` from the JSON
3. **TypeScript generation**: the same script generates `raycast/src/data/timezones.ts`

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

1. **Raycast LocalStorage**: Raycast stores add/edit/remove zone changes locally for the extension. The macOS app's `UserDefaults` zone list is separate.
2. **URL scheme**: The app registers `timezoner://` — the extension opens `timezoner://open` or `timezoner://set?hour=15&minute=0&zone=America%2FLos_Angeles&label=SF`.
3. **Fallback**: If the app isn't installed, the extension works standalone with its own zones and copy actions.

## Data Size

| Component | Size |
|-----------|------|
| timezone-aliases.json | ~15KB |
| parser.ts | ~260 lines |
| convert-time.tsx | ~640 lines |
| map-preview.ts | ~450 lines |
| timezone-boundaries.json | bundled GeoJSON boundary data; keep ODbL/OpenStreetMap attribution |
| **Total extension** | one command plus bundled offline data |

## Publishing

The extension is implemented and source-installable from `raycast/`. Store submission PR: https://github.com/raycast/extensions/pull/29168.

Manual store distribution path:

1. Fork `github.com/raycast/extensions`
2. Add extension under `extensions/timezoner/`
3. Submit PR with README, icon, screenshots
4. Raycast team reviews
5. Appears in Raycast Store

## Out of Scope (v1)

- Syncing zone list between app and extension (Raycast uses separate LocalStorage preferences initially)
- Calendar integration
- Meeting time suggestion ("find overlap")
- Relative time queries ("3 hours from now in Tokyo")

## Success Criteria

1. Type `tz 3pm in SF` → see card results quickly
2. All 376 aliases resolve correctly
3. Empty query shows saved-zone clock cards and the map preview
4. Card edit mode retargets cleanly when selecting another card
5. Copy-to-clipboard works for quick pasting into Slack/email
6. Source extension passes tests, lint, and build before store submission
7. Standalone — works without TimeZoner.app installed

## Open Questions

1. Default home zone: not implemented in v1; users configure default zones in Raycast preferences.
2. Relative queries: out of scope for v1.
3. Zone sync: stay independent for v1. Raycast uses LocalStorage; app integration is via `timezoner://`.
