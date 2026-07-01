# Product Requirements

## Active PRDs

| PRD | Status | Description |
|-----|--------|-------------|
| [Raycast Extension](2026-03-25-raycast-extension.md) | Implemented, source-installed | Natural language timezone conversion in Raycast search bar. Uses the generated 376-alias TypeScript table, Raycast-local zone persistence, and `timezoner://` app handoff. Store submission remains. |
| [Timezone Map](2026-03-24-timezone-map.md) | Implemented | Collapsible world timezone map below zone cards. GeoJSON-based, offline, highlights active zones, shows hover offsets, and supports click-to-add. |

## Monorepo Structure

TimeZoner is a monorepo containing both the macOS app and the Raycast extension:

```
TimeZoner/
├── app/          # macOS SwiftUI app
├── raycast/      # Raycast extension (TypeScript)
├── shared/       # Shared data (timezone aliases JSON)
├── scripts/      # Build, package, and sync scripts
└── docs/         # Documentation and PRDs
```

The timezone alias table (`shared/timezone-aliases.json`) is the single source of truth. Build scripts generate platform-specific formats (Swift dict, TypeScript map) from this shared data.

Distribution readiness is tracked in [../RELEASE_READINESS.md](../RELEASE_READINESS.md).
