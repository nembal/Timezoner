# Product Requirements

## Active PRDs

| PRD | Status | Description |
|-----|--------|-------------|
| [Raycast Extension](2026-03-25-raycast-extension.md) | Planned | Natural language timezone conversion in Raycast search bar. Ports the 376-alias table and parser to TypeScript. |
| [Timezone Map](2026-03-24-timezone-map.md) | Planned | Collapsible world timezone map below zone cards. GeoJSON-based, offline, highlights active zones. |

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
