# PRD: Interactive Timezone Map

**Status:** Implemented.

## Overview

Add a collapsible world timezone map below the zone cards. The map highlights which timezone regions are currently active/selected, provides visual geographic context for the time conversion, shows current offset information on hover, and supports click-to-add for new zone cards. The core chat + card workflow remains primary.

## Problem

When working across many timezones, it's hard to mentally place where each zone is geographically. A visual map anchors the abstract "+14h" into physical locations. It also makes the app look polished and distinctive — no other lightweight timezone tool has this.

## Goal

A minimal, beautiful, offline timezone map that highlights active zones with the terracotta accent color. Collapsible so it doesn't take space when not needed.

## User Stories

1. **As a user**, I can expand a map below my timezone cards to see where my zones are in the world.
2. **As a user**, when I type `3pm SF` in the chat, the SF timezone region highlights on the map.
3. **As a user**, when I type `1130am BKK in SF`, both BKK and SF regions highlight.
4. **As a user**, I can collapse the map to keep the app compact.
5. **As a user**, I can hover a region to see its GMT offset.
6. **As a user**, I can click a timezone region to add it as a card.
7. **As a user**, the map works offline with no network dependency.

## Design

### Layout

```
┌─────────────────────────────────────┐
│  ─── drag pill ───                  │
│  [chat field]           [Now]  [?]  │
│  [BKK] →+14h→ [SF] →+3h→ [NY]      │
│                                     │
│  ▾ Map                              │  ← chevron toggle
│  ┌─────────────────────────────────┐│
│  │  ██ highlighted  ░░ other zones ││
│  │  [simplified world map]         ││
│  │  timezone regions as polygons   ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### Visual Style

- Flat equirectangular projection (simple, familiar)
- Timezone regions as filled polygons
- Default: subtle warm fill (Theme.cardBg) with thin borders (Theme.border)
- Highlighted zones: terracotta fill (Theme.accent at ~30% opacity) with solid terracotta border
- Follows existing highlight system — same zones that get orange card borders also glow on the map
- Dark mode: darker fills, same terracotta highlights
- No country labels or grid lines — clean and minimal
- City dots mark the user's saved zones
- Map height: 320px, spans full card width

### Interaction

- **Collapse/expand**: chevron button toggles map visibility, state persisted to UserDefaults
- **Hover**: shows the region's current GMT offset and highlights matching-offset bands
- **Click**: adds a card for the clicked timezone if it is not already in the user's zone list

### Animation

- Highlight zones animate in/out with the same timing as card highlights (0.2s in, 0.5s fade after 3s)
- Map expand/collapse with `.easeInOut(duration: 0.25)`

## Technical Approach

### Data Source

**Primary:** `2025b-combined-simplified.json` from [zones-arilyn-cc](https://github.com/KevinNovak/zones-arilyn-cc)
- 1.4MB GeoJSON, 419 IANA timezone features
- Already simplified (~64K coordinate points)
- Data license: ODbL (OpenStreetMap derived) — requires attribution
- Can further simplify with Mapshaper if needed (~500KB target)

**Alternative:** `timezones.json` from [timezone-picker](https://github.com/kevalbhatt/timezone-picker)
- 124KB, pre-projected screen coordinates
- MIT licensed
- Lower fidelity but much smaller

**Fallback:** [dejurin/simplified-timezone-boundaries](https://github.com/dejurin/simplified-timezone-boundaries)
- 325KB, 419 zones, 14K points
- MIT licensed

### Rendering

SwiftUI `Canvas` with `Path` — no external rendering dependencies.

```swift
struct TimezoneMapView: View {
    let zones: [ZoneInfo]
    let highlightedZoneIds: Set<UUID>

    var body: some View {
        Canvas { context, size in
            for feature in geoData.features {
                let path = projectFeature(feature, into: size)
                let isHighlighted = isZoneHighlighted(feature.tzid)
                context.fill(path, with: .color(isHighlighted ? accentFill : defaultFill))
                context.stroke(path, with: .color(borderColor), lineWidth: 0.5)
            }
        }
    }
}
```

### Projection

Equirectangular (simplest, works well for flat timezone bands):

```swift
func project(lon: Double, lat: Double, size: CGSize) -> CGPoint {
    let x = (lon + 180) / 360 * size.width
    let y = (90 - lat) / 180 * size.height
    return CGPoint(x: x, y: y)
}
```

### GeoJSON Parsing

Lightweight Codable structs — no external dependencies:

```swift
struct GeoJSONFeatureCollection: Codable {
    let features: [GeoJSONFeature]
}
struct GeoJSONFeature: Codable {
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}
struct GeoJSONProperties: Codable {
    let tzid: String
}
```

### Highlight Matching

Map IANA timezone IDs from the GeoJSON (`America/Los_Angeles`) to the user's zone cards via `ZoneInfo.timeZoneId`. When `highlightedZoneIds` contains a card whose `timeZoneId` matches a GeoJSON feature's `tzid`, that feature renders highlighted.

### File Structure

```
app/Sources/
  Views/
    TimezoneMapView.swift   # Canvas renderer, toggle, hover, click-to-add
  Utilities/
    MapProjection.swift     # Projection and path construction
    MapColorLogic.swift     # Highlight/user/hover band visual state
  Data/
    GeoJSONTypes.swift      # Codable structs and bundle lookup
    CityCoordinates.swift   # City dot coordinates
  Resources/
    timezone-boundaries.json  # Bundled GeoJSON (~328KB)
```

## Data Size Budget

| Component | Size |
|-----------|------|
| GeoJSON boundaries | ~328KB |
| GeoJSON parser code | ~100 lines |
| Map renderer code | ~150 lines |
| Toggle UI code | ~30 lines |
| **Total code** | ~280 lines |
| **Total bundle impact** | ~328KB data plus renderer code |

The shipped resource is 332,741 bytes. It is small enough for the local-first app and is copied into `TimeZoner_TimeZonerLib.bundle` by the build, install, Homebrew, and DMG packaging paths.

## Attribution

If using ODbL-licensed data (timezone-boundary-builder derived), add to the help popover or a small "i" on the map:

> Timezone boundaries: OpenStreetMap contributors (ODbL)

If using MIT-licensed alternatives (timezone-picker, dejurin), no attribution required.

## Out of Scope (v1)

- Zoom/pan on map
- Country/city labels
- Country borders (only timezone regions)
- Animated day/night shadow
- Alternative projections (Mercator, Robinson)

## Success Criteria

1. Map renders all timezone regions correctly with no visual glitches
2. Highlighted zones match the card highlight system exactly
3. Map works in both light and dark mode
4. Expand/collapse persists across launches
5. No perceptible lag when rendering (Canvas should handle 64K points smoothly)
6. Total bundle size increase < 1.5MB
7. Zero network calls

## Open Questions

1. GeoJSON size: resolved at ~328KB.
2. Default state: expanded on first launch and persisted with `@AppStorage("mapExpanded")`.
3. Toggle visibility: always shown as the map section control.
