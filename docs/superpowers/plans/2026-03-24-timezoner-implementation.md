# TimeZoner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight SwiftUI Mac floating-panel app for instant timezone conversion with natural language input, editable zone cards, and a horizontal time scrubber.

**Architecture:** Swift Package with manual .app bundling. NSPanel (AppKit) hosts SwiftUI views. Single `TimeState` `@Observable` class (Observation framework, macOS 14+) drives all views — editing any input (chat field, zone card, scrubber) updates the reference time, and every zone card recomputes. Views consume `@Observable` types via `@State` / `@Bindable` (NOT `@StateObject` / `@ObservedObject`). Timezone alias data is bundled as a static Swift dictionary.

**Tech Stack:** SwiftUI, AppKit (NSPanel), Swift Package Manager, macOS 14+

**Design doc:** `docs/plans/2026-03-24-timezoner-design.md`

---

## File Structure

```
TimeZoner/
├── Package.swift
├── Sources/
│   ├── App/
│   │   ├── TimeZonerApp.swift          # @main, NSApplicationDelegateAdaptor
│   │   └── FloatingPanel.swift         # NSPanel subclass, window setup
│   ├── Models/
│   │   ├── TimeState.swift             # Reference time + source zone (@Observable)
│   │   └── ZoneInfo.swift              # Single zone model (id, label, timeZone)
│   ├── Stores/
│   │   └── ZoneStore.swift             # Active zones list, UserDefaults persistence
│   ├── Data/
│   │   └── TimezoneAliases.swift       # Static alias table: city/abbreviation → IANA id
│   ├── Parser/
│   │   └── InputParser.swift           # Natural language time+zone parser
│   ├── Views/
│   │   ├── ContentView.swift           # Main layout: chat + cards + scrubber
│   │   ├── ChatField.swift             # Top input field with parsing
│   │   ├── ZoneCard.swift              # Single editable timezone card
│   │   ├── ZoneCardRow.swift           # Horizontal ScrollView of zone cards
│   │   └── TimeScrubber.swift          # Horizontal time strip
│   └── Utilities/
│       └── TimeFormatter.swift         # Shared time formatting helpers
├── Tests/
│   ├── InputParserTests.swift          # Parser unit tests
│   ├── TimezoneAliasTests.swift        # Alias resolution tests
│   ├── TimeStateTests.swift            # Time conversion logic tests
│   ├── ZoneStoreTests.swift            # Persistence tests
│   └── TimeFormatterTests.swift        # Formatting & relative offset tests
├── Info.plist
├── build.sh                            # swift build + .app assembly
└── docs/
    └── plans/
        └── 2026-03-24-timezoner-design.md
```

---

### Task 1: Project Scaffold & Floating Panel

**Files:**
- Create: `Package.swift`
- Create: `Sources/App/TimeZonerApp.swift`
- Create: `Sources/App/FloatingPanel.swift`
- Create: `Sources/Views/ContentView.swift`
- Create: `Info.plist`
- Create: `build.sh`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeZoner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimeZoner",
            path: "Sources"
        ),
        .testTarget(
            name: "TimeZonerTests",
            dependencies: ["TimeZoner"],
            path: "Tests"
        )
    ]
)
```

- [ ] **Step 2: Create FloatingPanel.swift**

```swift
import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 280),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        self.contentView = contentView
    }
}
```

- [ ] **Step 3: Create TimeZonerApp.swift**

The `@main` entry point. Uses `NSApplicationDelegateAdaptor` to create the floating panel. Sets activation policy to `.accessory` (no dock icon). Hosts the SwiftUI ContentView inside the panel.

- [ ] **Step 4: Create a placeholder ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("TimeZoner")
                .font(.system(.title, design: .rounded))
        }
        .frame(width: 700, height: 280)
        .background(.ultraThinMaterial)
    }
}
```

- [ ] **Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.timezoner.app</string>
    <key>CFBundleName</key>
    <string>TimeZoner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>TimeZoner</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 6: Create build.sh**

```bash
#!/bin/bash
set -e
swift build -c release
rm -rf TimeZoner.app
mkdir -p TimeZoner.app/Contents/MacOS
mkdir -p TimeZoner.app/Contents/Resources
cp .build/release/TimeZoner TimeZoner.app/Contents/MacOS/
cp Info.plist TimeZoner.app/Contents/
echo "Built TimeZoner.app"
```

- [ ] **Step 7: Build and verify the floating panel appears**

```bash
chmod +x build.sh && ./build.sh && open TimeZoner.app
```

Expected: A floating translucent window appears with "TimeZoner" text. No dock icon.

- [ ] **Step 8: Commit**

```bash
git init && git add -A && git commit -m "feat: project scaffold with floating panel"
```

---

### Task 2: Timezone Alias Data

**Files:**
- Create: `Sources/Data/TimezoneAliases.swift`
- Create: `Tests/TimezoneAliasTests.swift`

- [ ] **Step 1: Write failing tests for alias resolution**

Test that `resolveTimezone("SF")` returns `"America/Los_Angeles"`, `resolveTimezone("BKK")` returns `"Asia/Bangkok"`, `resolveTimezone("bangkok")` returns `"Asia/Bangkok"`, `resolveTimezone("Europe")` returns `"Europe/Paris"`, etc. Test case-insensitivity. Test unknown input returns nil.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter TimezoneAliasTests
```

- [ ] **Step 3: Implement TimezoneAliases.swift**

A static dictionary mapping lowercase aliases to IANA identifiers. Categories:
- City abbreviations: SF, NYC, NY, HK, BKK, LA, etc.
- City names: "san francisco", "new york", "bangkok", "hong kong", "tokyo", "london", "paris", "berlin", etc.
- Country names: "thailand", "japan", "germany", "france", "uk", etc.
- Region aliases: "europe" → Europe/Paris, "pacific" → America/Los_Angeles
- Timezone abbreviations: PT, PST, PDT, ET, EST, EDT, CT, CST, CDT, MT, MST, MDT, CET, CEST, GMT, UTC, ICT, JST, HKT, SGT, AEST, AEDT, IST, BST
- Airport codes (top 50): LAX, SFO, JFK, EWR, LHR, CDG, NRT, HND, HKG, SIN, BKK, ICN, DXB, AMS, FRA, ZRH, MUC, FCO, MAD, BCN, SEA, ORD, ATL, DFW, MIA, BOS, IAD, DEN, YYZ, YVR, MEX, GRU, SCL, SYD, MEL, AKL, PEK, PVG, CAN, KIX, TPE, DEL, BOM, DOH, IST, CAI, JNB, NBO, etc.

Total entries target: ~100 custom aliases + ~150 city names + ~50 airport codes = ~300 entries in the dictionary. This covers the vast majority of lookups without needing external data files.

A `resolveTimezone(_ input: String) -> TimeZone?` function that lowercases input, strips whitespace, and looks up in the dictionary. Falls back to `TimeZone(identifier:)` and `TimeZone(abbreviation:)`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter TimezoneAliasTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/Data/ Tests/TimezoneAliasTests.swift && git commit -m "feat: timezone alias resolution with city/airport/abbreviation support"
```

---

### Task 3: Models — TimeState & ZoneInfo

**Files:**
- Create: `Sources/Models/TimeState.swift`
- Create: `Sources/Models/ZoneInfo.swift`
- Create: `Tests/TimeStateTests.swift`

- [ ] **Step 1: Write failing tests for time conversion**

Test that setting a reference time of 11:30 AM in Bangkok (ICT, UTC+7) correctly converts to:
- 9:30 PM previous day in SF (PT, UTC-7 or -8 depending on DST)
- 12:30 AM in NY (ET)
- 5:30 AM in CET

Use a fixed date to avoid DST ambiguity in tests.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter TimeStateTests
```

- [ ] **Step 3: Implement ZoneInfo**

```swift
import Foundation

struct ZoneInfo: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String        // Display name: "Bangkok", "SF", "New York"
    var timeZoneId: String   // IANA: "Asia/Bangkok"

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? .current
    }
}
```

- [ ] **Step 4: Implement TimeState**

```swift
import Foundation
import SwiftUI

@Observable
class TimeState {
    var referenceDate: Date = Date()  // The moment being converted
    var sourceZoneId: String = TimeZone.current.identifier

    func time(in zone: TimeZone) -> Date {
        // referenceDate is already an absolute moment — just format in different zones
        referenceDate
    }

    func setTime(hour: Int, minute: Int, in zone: TimeZone) {
        // Build a date from h:m in the given zone, keeping today's date
        var calendar = Calendar.current
        calendar.timeZone = zone
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = hour
        newComponents.minute = minute
        if let newDate = calendar.date(from: newComponents) {
            referenceDate = newDate
            sourceZoneId = zone.identifier
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter TimeStateTests
```

- [ ] **Step 6: Commit**

```bash
git add Sources/Models/ Tests/TimeStateTests.swift && git commit -m "feat: TimeState and ZoneInfo models with timezone conversion"
```

---

### Task 4: ZoneStore — Persistence

**Files:**
- Create: `Sources/Stores/ZoneStore.swift`
- Create: `Tests/ZoneStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Test that ZoneStore initializes with default zones (Bangkok, SF, NY, Europe). Test adding a zone. Test removing a zone. Test that zones round-trip through JSON encoding/decoding (simulating UserDefaults persistence).

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter ZoneStoreTests
```

- [ ] **Step 3: Implement ZoneStore**

`@Observable` class. Holds `[ZoneInfo]`. On init, loads from UserDefaults or falls back to defaults. On change, saves to UserDefaults as JSON. Methods: `add(label:timezoneId:)`, `remove(id:)`, `move(from:to:)` for reordering.

Default zones:
```swift
static let defaults: [ZoneInfo] = [
    ZoneInfo(id: UUID(), label: "Bangkok", timeZoneId: "Asia/Bangkok"),
    ZoneInfo(id: UUID(), label: "SF", timeZoneId: "America/Los_Angeles"),
    ZoneInfo(id: UUID(), label: "New York", timeZoneId: "America/New_York"),
    ZoneInfo(id: UUID(), label: "Europe", timeZoneId: "Europe/Paris"),
]
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ZoneStoreTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/Stores/ Tests/ZoneStoreTests.swift && git commit -m "feat: ZoneStore with UserDefaults persistence"
```

---

### Task 5: Input Parser

**Files:**
- Create: `Sources/Parser/InputParser.swift`
- Create: `Tests/InputParserTests.swift`

- [ ] **Step 1: Write failing tests for time parsing**

Test all input variants from the design doc:
```
"11:30am PT"      → hour:11, min:30, zone:America/Los_Angeles
"11:30 am PT"     → same (space before am)
"1130am PT"       → same (no colon)
"1130 am PT"      → same
"1130 a BKK"      → hour:11, min:30, zone:Asia/Bangkok
"3 p SF"          → hour:15, min:0, zone:America/Los_Angeles
"11:30 a.m. NYC"  → hour:11, min:30, zone:America/New_York
"3pm bangkok"     → hour:15, min:0, zone:Asia/Bangkok
"15:00 BKK"       → hour:15, min:0, zone:Asia/Bangkok
"noon NYC"        → hour:12, min:0
"midnight CET"    → hour:0, min:0
```

Test add/remove commands:
```
"+Tokyo"       → .addZone("Tokyo")
"add HK"       → .addZone("HK")
"-SF"          → .removeZone("SF")
"remove NYC"   → .removeZone("NYC")
```

Test invalid input returns nil.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter InputParserTests
```

- [ ] **Step 3: Implement InputParser**

Returns an enum:
```swift
enum ParseResult {
    case timeConversion(hour: Int, minute: Int, zone: TimeZone)
    case addZone(label: String, zone: TimeZone)
    case removeZone(label: String)
}

struct InputParser {
    static func parse(_ input: String) -> ParseResult?
}
```

Parsing strategy:
1. Check for add/remove commands first (`+`, `-`, `add `, `remove `)
2. Normalize: lowercase, trim whitespace
3. Handle "noon" → 12:00, "midnight" → 00:00
4. Regex patterns (tried in order):
   - `(\d{1,2}):(\d{2})\s*(a\.?m?\.?|p\.?m?\.?)?\s+(.+)` — "11:30 am PT"
   - `(\d{3,4})\s*(a\.?m?\.?|p\.?m?\.?)?\s+(.+)` — "1130am PT"
   - `(\d{1,2})\s*(a\.?m?\.?|p\.?m?\.?)\s+(.+)` — "3 p SF"
   - `(\d{1,2}):(\d{2})\s+(.+)` — "15:00 BKK" (24h, no am/pm)
5. Extract hour, minute, am/pm indicator, zone string
6. Resolve zone string via `resolveTimezone()`
7. Convert hour to 24h if pm indicator present

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter InputParserTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/Parser/ Tests/InputParserTests.swift && git commit -m "feat: forgiving natural language time parser"
```

---

### Task 6: Time Formatting Utilities

**Files:**
- Create: `Sources/Utilities/TimeFormatter.swift`
- Create: `Tests/TimeFormatterTests.swift`

- [ ] **Step 1: Write failing tests for TimeFormatter**

Test `formatTime` produces "11:30 AM" for a known date in a known zone. Test `formatDate` produces "Mon, Mar 24". Test `relativeOffset` edge cases:
- Bangkok → SF = "-14h" (or "-13h" during DST)
- Same zone → "+0h"
- Across day boundary → "+1d" or similar
- Use fixed dates to pin DST state.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter TimeFormatterTests
```

- [ ] **Step 3: Implement TimeFormatter**

Helpers used by views:
```swift
struct TimeFormatter {
    /// "11:30 AM" — for zone cards
    static func formatTime(_ date: Date, in zone: TimeZone) -> String

    /// "11:30" — for editable text field (no AM/PM, 24h if user prefers)
    static func formatTimeEditable(_ date: Date, in zone: TimeZone) -> String

    /// "Mon, Mar 24" — for date display
    static func formatDate(_ date: Date, in zone: TimeZone) -> String

    /// "+7h" or "-1d" — relative offset from a reference zone
    static func relativeOffset(from: TimeZone, to: TimeZone, at date: Date) -> String
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter TimeFormatterTests
```

- [ ] **Step 5: Verify dark/light mode**

Both `.ultraThinMaterial` and `.regularMaterial` adapt automatically. No extra work needed, but verify visually by toggling System Preferences → Appearance during testing.

- [ ] **Step 6: Commit**

```bash
git add Sources/Utilities/ Tests/TimeFormatterTests.swift && git commit -m "feat: time formatting utilities with tests"
```

---

### Task 7: Zone Card View

**Files:**
- Create: `Sources/Views/ZoneCard.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Implement ZoneCard**

A single timezone card. Displays:
- Zone label (e.g., "Bangkok") — top, smaller text
- Time (e.g., "11:30 AM") — large, SF Pro Rounded ~32pt, editable on click
- Date (e.g., "Mon, Mar 24") — small, below time
- Relative offset (e.g., "+7h from SF") — subtle text
- "x" button to remove (appears on hover)

When the time text is clicked, it becomes an editable TextField. Typing a new time and pressing Enter updates `TimeState`. The active card gets an accent-colored border/glow.

Use smooth animations: `.animation(.easeInOut(duration: 0.2), value: ...)` on time changes.

Rounded rect with soft shadow, no hard borders. `.background(.regularMaterial)` for each card.

- [ ] **Step 2: Commit**

```bash
git add Sources/Views/ZoneCard.swift && git commit -m "feat: editable zone card view"
```

---

### Task 8: Zone Card Row (Horizontal Layout)

**Files:**
- Create: `Sources/Views/ZoneCardRow.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Implement ZoneCardRow**

A horizontal `ScrollView(.horizontal)` containing all zone cards. Uses `LazyHStack` with spacing. Cards slide in/out with `.transition(.move(edge: .trailing).combined(with: .opacity))` when added/removed.

- [ ] **Step 2: Wire into ContentView**

ContentView now shows the ZoneCardRow, passing in `ZoneStore.zones` and `TimeState`.

- [ ] **Step 3: Build and verify cards display**

```bash
./build.sh && open TimeZoner.app
```

Expected: Four cards (Bangkok, SF, NY, Europe) showing current times.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/ && git commit -m "feat: horizontal zone card row"
```

---

### Task 9: Chat Field

**Files:**
- Create: `Sources/Views/ChatField.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Implement ChatField**

A styled TextField at the top of the window. Placeholder: "11:30am SF, +Tokyo, -NYC..."

On submit (Enter key):
1. Parse input via `InputParser.parse()`
2. If `.timeConversion`: update `TimeState`
3. If `.addZone`: resolve timezone, add to `ZoneStore`
4. If `.removeZone`: remove from `ZoneStore`
5. If parse fails: shake animation on the field
6. Clear the field after successful parse

Styling: rounded rect, `.textFieldStyle(.plain)`, custom padding, subtle border, SF Pro Rounded font. Focused on app launch (auto first responder).

Shake animation on parse failure:
```swift
.offset(x: shakeOffset)
.animation(.default, value: shakeOffset)
```

- [ ] **Step 2: Wire into ContentView**

ContentView layout is now: ChatField (top) → ZoneCardRow (middle).

- [ ] **Step 3: Build and verify chat input works**

```bash
./build.sh && open TimeZoner.app
```

Type "3pm BKK" → all cards should update.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/ && git commit -m "feat: chat field with natural language parsing"
```

---

### Task 10: Time Scrubber

**Files:**
- Create: `Sources/Views/TimeScrubber.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Implement TimeScrubber**

Horizontal strip at the bottom. Shows 30-minute increment markers spanning ±12 hours from current reference time.

Visual design:
- Pill-shaped track background (`.background(.regularMaterial)` with `clipShape(Capsule())`)
- Draggable indicator (circle or pill)
- Time labels at each 30-min mark, fading in/out based on proximity to center
- Current selection highlighted at center

Interaction:
- Drag gesture updates `TimeState.referenceDate` in real time
- Scroll gesture (trackpad) also works
- Snaps to 30-minute increments on release
- All zone cards update as you drag

- [ ] **Step 2: Wire into ContentView**

Final layout: ChatField (top) → ZoneCardRow (middle) → TimeScrubber (bottom).

- [ ] **Step 3: Build and verify scrubber works**

```bash
./build.sh && open TimeZoner.app
```

Drag scrubber → all times update smoothly.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/ && git commit -m "feat: horizontal time scrubber with 30-min increments"
```

---

### Task 11: Window Sizing & Polish

**Files:**
- Modify: `Sources/App/FloatingPanel.swift`
- Modify: `Sources/Views/ContentView.swift`
- Modify: `Sources/Views/ZoneCard.swift`

- [ ] **Step 1: Dynamic window width**

Window width adjusts based on number of zone cards. Each card ~150px wide + spacing. Minimum width for 2 cards, maximum for ~8. Animate window resize when cards are added/removed.

- [ ] **Step 2: Keyboard shortcuts**

- `Cmd+W` or `Escape`: hide window
- `Cmd+N`: focus chat field
- Click outside window: hide (panel behavior)

- [ ] **Step 3: Auto-focus chat field on launch**

The chat TextField receives focus immediately when the panel appears.

- [ ] **Step 4: "Now" indicator**

A small button or label showing "now" that resets `TimeState.referenceDate` to `Date()` when clicked. Visible when the reference time has been manually adjusted.

- [ ] **Step 5: Build and verify everything works together**

```bash
./build.sh && open TimeZoner.app
```

Full flow: type "11:30am BKK" → cards update → drag scrubber → cards update → click card time, edit → other cards update → type "+Tokyo" → new card slides in → type "-Europe" → card slides out.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: window sizing, keyboard shortcuts, polish"
```

---

### Task 12: Menu Bar Icon (Basic)

**Files:**
- Modify: `Sources/App/TimeZonerApp.swift`

- [ ] **Step 1: Add a menu bar button**

Add an `NSStatusItem` with a clock icon (SF Symbol `clock.fill`). Clicking it toggles the floating panel's visibility. This gives users a way to re-show the panel after dismissing it.

- [ ] **Step 2: Build and verify**

```bash
./build.sh && open TimeZoner.app
```

Expected: Clock icon in menu bar. Click shows/hides the floating panel.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/ && git commit -m "feat: menu bar icon to toggle panel"
```
