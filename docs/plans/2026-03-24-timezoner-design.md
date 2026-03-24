# TimeZoner — Design Document

## Overview

A lightweight SwiftUI Mac app for instant time zone conversion. Floating panel, no dock icon, launches fast for Spotlight/Raycast users. Modern 2026 UI.

## Core Interaction

Two input modes that stay in sync:

1. **Chat field** (top) — type natural language like "11:30am PT" or "3pm Bangkok" and all zone cards update. Also used to add/remove zones.
2. **Zone cards** (middle) — horizontal row of editable cards, one per zone. Click any card's time to edit directly; all others update.
3. **Time scrubber** (bottom) — horizontal strip of 30-min increments. Drag to update all cards simultaneously.

## Default Zones

Bangkok (ICT), San Francisco (PT), New York (ET), Europe/CET (Paris/Berlin).

User can add/remove zones dynamically. Number of columns is flexible.

## Window Behavior

- Floating panel (NSPanel, .floating level)
- Always on top, no dock icon
- Compact: width scales with number of zone cards, ~250px tall
- Translucent vibrancy background (.ultraThinMaterial)
- Menu bar icon version planned for later

## Visual Design

- Translucent glass-like background
- SF Pro Rounded, ~32pt for times
- Soft rounded rect cards, no hard borders
- Accent color on active/editing card
- Smooth crossfade animations on time updates
- Cards slide in/out on add/remove
- Sleek pill-shaped scrubber track
- Native dark/light mode (follows system)
- Generous whitespace, breathable layout

## Chat Parser

Forgiving natural language parser. Accepts:

- `11:30am PT`, `11:30 am PT`, `1130am PT`, `1130 am PT`
- `11:30 a.m. PT`, `1130 a BKK`, `3 p SF`
- `3pm bangkok`, `15:00 BKK`, `noon NYC`, `midnight CET`
- `am`, `a.m.`, `a`, `pm`, `p.m.`, `p` — all case-insensitive, space optional
- `+Tokyo` or `add HK` to add zones
- `-SF` or `remove NYC` to remove zones

Parsing strategy: regex-based, multiple pattern attempts, strips noise, normalizes case, fuzzy-matches against alias table. On failure: gentle shake animation, no error dialogs.

## Timezone Resolution

Layered lookup (checked in order):

1. **Custom alias table** (~100 entries): SF, NYC, HK, BKK, "Europe", etc.
2. **City name lookup**: ~200 curated cities from city-timezones dataset
3. **Airport IATA codes**: top 50 airports (BKK, LAX, CDG, etc.)
4. **Apple TimeZone identifiers**: fallback

All bundled in the app. No network required.

## Architecture

- `TimeZoneStore` (ObservableObject) — list of active zones, persisted to UserDefaults
- `TimeState` (ObservableObject) — the "reference time" being converted. Single source of truth updated by chat field, zone cards, or scrubber.
- Each zone card: pure function of `referenceTime + sourceZone → displayTime`
- No server, no API keys, no network for v1

## Tech Stack

- SwiftUI, macOS 14+
- NSPanel for floating window behavior
- Native TimeZone API for DST handling

## Future (v2)

- Menu bar icon mode
- Raycast extension
- Flight tracking (AviationStack or AeroDataBox free tier)
- Widget
