# Calendar Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only macOS Calendar companion, full Today/3 Days/Week views, event-to-timezone conversion, and optional TimeZoner-owned local notifications while preserving a path to a later full calendar app.

**Architecture:** Keep EventKit and UserNotifications behind async protocols that return TimeZoner-owned `Sendable` value types. Lift process-lifetime state into `AppDelegate`, route every reference-moment mutation through one controller, and coordinate the main and agenda panels explicitly. Build in three slices—packaged permission gate, calendar core, alerts—but execute them under one reviewed ledger because the later slices consume the exact interfaces established by the earlier ones.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit `NSPanel`, Observation, EventKit, UserNotifications, Swift Package Manager, executable `TimeZonerTests` target, macOS 14+

**Spec:** `docs/superpowers/specs/2026-09-24-calendar-companion-design.md`

## Global Constraints

- macOS 14+; use `@Observable`, not `ObservableObject`.
- Zero third-party dependencies, zero direct network clients, no Google OAuth, and no TimeZoner account.
- Calendar reads come only from the local EventKit database; never create, update, delete, accept, or decline events.
- Do not persist event titles, attendee identities, event times, calendar contents, OAuth credentials, or EventKit objects.
- EventKit objects and predicates stay on one serialized provider executor and never cross into views or tests.
- `TimeState.referenceDate` remains the single absolute moment used by cards and map; all writes route through `ReferenceMomentController`.
- `Show agenda wing` and global alerts default off. Newly discovered calendars default to `isVisible = true` and `alertsEnabled = true`.
- Calendar color is rendered as a quiet tint or 2–3 point marker, never a dominant block.
- Core must remain useful without alerts. Alerts consume core interfaces and do not redesign calendar UI.
- No background agent. Notification reconciliation covers the next seven days and documents that limitation.
- Use the executable `TimeZonerTests` target; automated tests must use fakes and must never prompt for system permission.
- No deployment, release, tag, Homebrew formula update, push, or external publication.

---

### Task 1: Packaged Calendar Permission Risk Gate

**Files:**
- Create: `app/Sources/Models/CalendarModels.swift`
- Create: `app/Sources/Utilities/CalendarEventReading.swift`
- Create: `app/Sources/Utilities/EventKitCalendarProvider.swift`
- Create: `app/Sources/App/CalendarPermissionProbeView.swift`
- Create: `app/Tests/CalendarProviderTests.swift`
- Create: `docs/verification/calendar-permission-spike-2026-09-24.md`
- Modify: `app/Info.plist`
- Modify: `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: `CalendarAuthorizationStatus`, `CalendarColor`, `CalendarDescriptor`, `CalendarEventSnapshot`, `EventAvailability`, `EventParticipationStatus`, and `CalendarEventReading` exactly as the spec defines.
- Produces: `EventKitCalendarProvider: CalendarEventReading` with a single long-lived `EKEventStore`, serialized access, `changes: AsyncStream<Void>`, and no EventKit types in public signatures.
- Produces: launch argument `--calendar-permission-spike` that shows a minimal packaged probe containing status, `Enable Calendar`, a real calendar/event count after grant, and `Open Calendar Privacy Settings` after denial.
- Gate: do not begin Task 2 until the changed-rebuild and denial/recovery observations are recorded and judged stable for ordinary upgrades.

- [ ] **Step 1: Add failing provider mapping tests**

Add `runCalendarProviderTests()` with deterministic pure-mapping assertions for normalized RGBA components, `Untitled event`, owner-declined filtering, cancelled filtering, attendee fallback to email/name supplied by the mapper input, tentative availability, and occurrence IDs formatted as `<calendarItemIdentifier>|<startDate.timeIntervalSince1970>`.

- [ ] **Step 2: Run the tests and verify failure**

Run: `cd app && swift run TimeZonerTests`

Expected: compilation fails because the calendar model and mapper types do not exist.

- [ ] **Step 3: Implement the value model, protocol, and EventKit adapter**

Use these public signatures:

```swift
public enum CalendarAuthorizationStatus: Equatable, Sendable {
    case notDetermined, restricted, denied, fullAccess, writeOnly
}

public struct CalendarColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
}

public enum EventAvailability: Equatable, Sendable { case busy, free, tentative, unavailable }
public enum EventParticipationStatus: Equatable, Sendable { case unknown, pending, accepted, declined, tentative, delegated, completed, inProcess }

public protocol CalendarEventReading: AnyObject {
    var authorizationStatus: CalendarAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func calendars() async throws -> [CalendarDescriptor]
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) async throws -> [CalendarEventSnapshot]
    var changes: AsyncStream<Void> { get }
}
```

Map `EKParticipantStatus.declined` only from `event.organizer?.participantStatus` when the organizer is the current user; do not infer owner decline from other attendees. Omit `EKEventStatus.canceled`. Map and copy every EventKit value inside the provider's serialized executor before returning.

- [ ] **Step 4: Add the exact full-access usage description and probe route**

Add to `app/Info.plist`:

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>TimeZoner reads your calendars to show upcoming events across your saved time zones.</string>
```

When `ProcessInfo.processInfo.arguments.contains("--calendar-permission-spike")`, make the packaged app root the probe view. The normal launch path remains unchanged.

- [ ] **Step 5: Verify automated tests and package**

Run: `cd app && swift run TimeZonerTests`

Expected: all tests pass and no permission dialog appears.

Run: `./install.sh`

Expected: `~/Applications/TimeZoner.app` builds, is ad-hoc signed, and installs successfully.

- [ ] **Step 6: Complete the real permission gate**

Launch `open --args "$HOME/Applications/TimeZoner.app" --calendar-permission-spike`. Record in the verification document: initial status, successful real fetch, exact installed path, `codesign -dr -` output, and macOS version. Quit; change the probe's compiled marker string from `calendar-probe-a` to `calendar-probe-b`; rebuild/reinstall at the same path; record whether access persists, re-prompts, denies, or needs System Settings. Revoke Calendar access, relaunch, use the recovery button, grant once more, and record the result. Restore the marker to the descriptive constant `calendar-permission-probe` before committing.

- [ ] **Step 7: Commit the gate**

```bash
git add app/Info.plist app/Sources/Models/CalendarModels.swift app/Sources/Utilities/CalendarEventReading.swift app/Sources/Utilities/EventKitCalendarProvider.swift app/Sources/App/CalendarPermissionProbeView.swift app/Sources/App/TimeZonerApp.swift app/Tests/CalendarProviderTests.swift app/Tests/TimeZonerTests.swift docs/verification/calendar-permission-spike-2026-09-24.md
git commit -m "feat: verify packaged calendar access"
```

### Task 2: Calendar Ranges, Layout Geometry, and Preferences

**Files:**
- Create: `app/Sources/Models/CalendarRange.swift`
- Create: `app/Sources/Models/CalendarLayout.swift`
- Create: `app/Sources/Stores/CalendarPreferenceStore.swift`
- Create: `app/Tests/CalendarRangeTests.swift`
- Create: `app/Tests/CalendarLayoutTests.swift`
- Create: `app/Tests/CalendarPreferenceStoreTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: `CalendarRangeSelection` cases `.today`, `.threeDays`, `.week`; `CalendarDateIntervalCalculator.interval(for:anchor:calendar:)`; and `movedAnchor(_:direction:range:calendar:)`.
- Produces: `CalendarLayoutEngine.timedSegments(events:interval:calendar:)`, `allDaySpans(events:interval:calendar:)`, and overlap lane assignment whose results carry the original occurrence ID.
- Produces: `CalendarPreferenceStore.preference(for:)`, `setVisible(_:calendarID:)`, `setAlertsEnabled(_:calendarID:)`, and persisted `CalendarPreference` values.

- [ ] **Step 1: Write failing deterministic tests**

Cover a DST spring-forward Today interval, anchored 3 Days, locale week honoring a non-Sunday `firstWeekday`, previous/next deltas, two overlapping events in separate lanes, a cross-midnight event split across local days with the same occurrence ID, a multi-day all-day span, discovery defaults, hidden/alert independence, and disappeared-calendar preference retention.

- [ ] **Step 2: Run tests and confirm missing-type failures**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement minimal pure calendar algorithms**

Use half-open date intervals `[start, end)`. For `.week`, derive the locale week with `calendar.dateInterval(of: .weekOfYear, for: anchor)`. Sort timed segments by start, then end, then occurrence ID; greedily reuse the first lane whose end is `<=` the next start, and report `laneCount` for every member of the overlap group.

- [ ] **Step 4: Implement preference persistence**

Encode `[String: CalendarPreference]` as JSON data in `UserDefaults`. Missing IDs return `CalendarPreference(isVisible: true, alertsEnabled: true)` without deleting saved IDs that are absent from the latest descriptor list.

- [ ] **Step 5: Run tests and commit**

Run: `cd app && swift run TimeZonerTests`

```bash
git add app/Sources/Models/CalendarRange.swift app/Sources/Models/CalendarLayout.swift app/Sources/Stores/CalendarPreferenceStore.swift app/Tests/CalendarRangeTests.swift app/Tests/CalendarLayoutTests.swift app/Tests/CalendarPreferenceStoreTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: add calendar range and preference models"
```

### Task 3: Shared Reference Moment Controller

**Files:**
- Create: `app/Sources/Models/ReferenceMomentController.swift`
- Create: `app/Tests/ReferenceMomentControllerTests.swift`
- Modify: `app/Sources/Views/ChatField.swift`
- Modify: `app/Sources/Views/ZoneCard.swift`
- Modify: `app/Sources/Views/ZoneCardRow.swift`
- Modify: `app/Sources/Views/ContentView.swift`
- Modify: `app/Tests/TimeZonerDeepLinkTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: `SelectedEventContext(id:title:startDate:)` and `@Observable ReferenceMomentController`.
- `selectEvent(_:sourceZone:)` selects timed events only, records context, and calls a `CalendarPresentationState` map-collapse hook introduced as the small protocol `EventSelectionPresenting`.
- `setTime(hour:minute:in:)`, `setDate(_:sourceZone:)`, and `goLive()` clear selected-event context before mutating `TimeState`.

- [ ] **Step 1: Write failing controller tests**

Assert timed selection updates date/source/live/context; all-day selection is ignored; a second event preserves the first map snapshot; chat/card/deep-link/date/Now mutations clear context; manual map toggling cancels auto-restore; ordinary clearing restores the pre-selection map state.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement controller and route every mutation**

Views receive `ReferenceMomentController` and may read its `timeState`, but must not call `TimeState.setTime` or `goLive`. Keep `TimeState` public mutation methods for controller/tests compatibility; enforce the product boundary through all production call sites.

- [ ] **Step 4: Add the selected-event context row**

Show title plus `MMM d · h:mm a z` in `TimeZone.current`, immediately above `ZoneCardRow`, only while context exists. `Now` calls the controller and restores map state through the presentation hook.

- [ ] **Step 5: Verify direct-call audit and commit**

Run: `rg -n "timeState\.(setTime|goLive)" app/Sources --glob '!Models/ReferenceMomentController.swift'`

Expected: no matches.

Run: `cd app && swift run TimeZonerTests`

```bash
git add app/Sources/Models/ReferenceMomentController.swift app/Sources/Views/ChatField.swift app/Sources/Views/ZoneCard.swift app/Sources/Views/ZoneCardRow.swift app/Sources/Views/ContentView.swift app/Tests/ReferenceMomentControllerTests.swift app/Tests/TimeZonerDeepLinkTests.swift app/Tests/TimeZonerTests.swift
git commit -m "refactor: centralize reference moment changes"
```

### Task 4: Calendar Store and Lifecycle Clock

**Files:**
- Create: `app/Sources/Stores/CalendarStore.swift`
- Create: `app/Sources/Utilities/CalendarClock.swift`
- Create: `app/Tests/CalendarStoreTests.swift`
- Create: `app/Tests/CalendarClockTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable CalendarStore` containing authorization, descriptors, last successful events, loading, stale marker, error text, and active interval.
- Produces: `refresh(interval:)`, `requestAccess()`, `handlePermissionChange()`, and `events(on:)`; every async request captures an incrementing generation and discards superseded success and failure results.
- Produces: injectable `CalendarClock` exposing `now`, `calendar`, minute/midnight/hour ticks, wake, activation, reopen, and timezone-change streams.

- [ ] **Step 1: Write async fake-provider tests**

Cover successful empty vs thrown failure, last-snapshot retention on fetch failure, hidden-calendar IDs excluded from UI fetches, superseded success/error rejection, store-change refetch, midnight/timezone range rebuilding, reopen/wake/activation authorization checks, and permission loss clearing events/context through a supplied callback.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement the main-actor store**

Never clear last successful same-generation snapshots on an ordinary fetch error; instead set `isStale = true`. On any non-full authorization transition, clear descriptors/events/error, cancel in-flight results by incrementing generation, and invoke `onPermissionLost` exactly once per full-to-unavailable transition.

- [ ] **Step 4: Implement wall-clock lifecycle streams**

Use `NSCalendarDayChanged`, `NSSystemTimeZoneDidChange`, `NSWorkspace.didWakeNotification`, and `NSApplication.didBecomeActiveNotification`; schedule minute and hourly timers on wall-clock boundaries. Tests inject streams and a fixed `now` closure.

- [ ] **Step 5: Run tests and commit**

Run: `cd app && swift run TimeZonerTests`

```bash
git add app/Sources/Stores/CalendarStore.swift app/Sources/Utilities/CalendarClock.swift app/Tests/CalendarStoreTests.swift app/Tests/CalendarClockTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: add calendar store lifecycle"
```

### Task 5: Shared App State, Panel Coordinator, and Agenda Wing

**Files:**
- Create: `app/Sources/Models/CalendarPresentationState.swift`
- Create: `app/Sources/Views/AgendaView.swift`
- Create: `app/Sources/Views/CalendarAccessView.swift`
- Create: `app/Sources/App/CalendarPanelCoordinator.swift`
- Create: `app/Tests/CalendarPanelCoordinatorTests.swift`
- Modify: `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Sources/App/FloatingPanel.swift`
- Modify: `app/Sources/Views/ContentView.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: process-lifetime ownership in `AppDelegate` of `TimeState`, `ReferenceMomentController`, `ZoneStore`, `CalendarStore`, `CalendarPreferenceStore`, and `CalendarPresentationState`.
- Produces: `CalendarPanelCoordinator` with explicit `mainPanel` and `agendaPanel`, pure placement calculation returning `.right`, `.left`, or `.popover`, and paired `show()`, `hide()`, `toggle()`, `resizeMain(to:)` operations.
- Produces: `AgendaView` for today, including earlier disclosure, all-day rows, title/time/attendee summary/calendar title, attendee popover, empty/stale/error/access states, subtle selection accent, and `Open week`.

- [ ] **Step 1: Write failing placement and pair-behavior tests**

Test right placement with 230+ free points, left fallback, popover fallback when neither side has 230 points, 10-point gap, top alignment, visible-frame clamping, explicit-main resize, Escape from either surface, focus transfer between owned surfaces, and hide only after neither panel nor an owned popover has focus.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Lift shared state and implement coordinator**

Remove private root stores from `ContentView`; inject them. `FloatingPanel.resignKey()` delegates dismissal decisions to the coordinator. The coordinator observes main-panel move/resize/screen/order notifications and recomputes attachment. The wing is 220 points wide and does not affect city-count width.

- [ ] **Step 4: Implement the agenda wing**

Format in `TimeZone.current`. Show two attendee names then `+ N`; the popover lists every supplied name. Omit owner-declined/cancelled snapshots already filtered by the provider. Make all-day rows non-selectable. When today is clear, show `Clear for the rest of today` and the next visible event tomorrow if fetched.

- [ ] **Step 5: Wire activation without unsolicited permission**

The quiet calendar glyph beside Settings starts the explanation when status is `.notDetermined`, opens recovery when unavailable, and toggles the wing after full access. `showAgendaWing` defaults false and no EventKit query or prompt occurs during ordinary first launch.

- [ ] **Step 6: Run tests, build, and commit**

Run: `cd app && swift run TimeZonerTests`

Run: `./scripts/build.sh`

```bash
git add app/Sources/Models/CalendarPresentationState.swift app/Sources/Views/AgendaView.swift app/Sources/Views/CalendarAccessView.swift app/Sources/App/CalendarPanelCoordinator.swift app/Sources/App/TimeZonerApp.swift app/Sources/App/FloatingPanel.swift app/Sources/Views/ContentView.swift app/Tests/CalendarPanelCoordinatorTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: add attached calendar agenda"
```

### Task 6: Today, 3 Days, and Week Calendar Mode

**Files:**
- Create: `app/Sources/Views/CalendarModeView.swift`
- Create: `app/Sources/Views/CalendarTimeGrid.swift`
- Create: `app/Tests/CalendarPresentationStateTests.swift`
- Modify: `app/Sources/Models/CalendarPresentationState.swift`
- Modify: `app/Sources/App/CalendarPanelCoordinator.swift`
- Modify: `app/Sources/Views/ContentView.swift`
- Modify: `app/Sources/Views/AgendaView.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- `CalendarPresentationState` owns destination `.timezoner` or `.calendar`, current range, anchor, and session-only last range.
- `CalendarModeView` consumes the Task 2 date interval/layout results and selects timed events through `ReferenceMomentController`.
- Coordinator targets 760×560 for calendar mode, clamps to visible frame, and restores the prior normal-mode frame on return.

- [ ] **Step 1: Write failing presentation tests**

Assert expand enters `.calendar` with `.week`, later entry remembers the session range, previous/next move by 1/3/locale-week units, Today resets anchor without changing `TimeState`, event selection returns to TimeZoner, and normal frame restoration is exact.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement calendar-mode navigation and sizing**

The header keeps the drag pill, quiet controls, segmented `Today / 3 Days / Week`, previous/next, Today, and `Back to TimeZoner`. Fetch exactly the active interval. Calendar dimensions never derive from city count.

- [ ] **Step 4: Implement the read-only grid**

Render a local-time day header, all-day row, 24-hour vertical scroll, current-time line when today is visible, overlap lanes, cross-midnight timed segments, and multi-day all-day spans. Apply calendar color only as `color.opacity(0.10)` fill and a 2-point leading indicator after clamping saturation to at most 0.55.

- [ ] **Step 5: Verify and commit**

Run: `cd app && swift run TimeZonerTests`

Run: `./scripts/build.sh`

```bash
git add app/Sources/Views/CalendarModeView.swift app/Sources/Views/CalendarTimeGrid.swift app/Sources/Models/CalendarPresentationState.swift app/Sources/App/CalendarPanelCoordinator.swift app/Sources/Views/ContentView.swift app/Sources/Views/AgendaView.swift app/Tests/CalendarPresentationStateTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: add read-only calendar views"
```

### Task 7: Calendar Settings and Permission-Loss Integration

**Files:**
- Modify: `app/Sources/Stores/SettingsStore.swift`
- Modify: `app/Sources/Views/SettingsPopover.swift`
- Modify: `app/Sources/Views/TimezoneMapView.swift`
- Modify: `app/Sources/Models/CalendarPresentationState.swift`
- Modify: `app/Sources/Stores/CalendarStore.swift`
- Modify: `app/Tests/SettingsStoreTests.swift`
- Modify: `app/Tests/CalendarStoreTests.swift`

**Interfaces:**
- Extends `SettingsStore.Keys` and persisted state with `showAgendaWing`, `alertsEnabled` default false, and `notificationLeadMinutes` default `[30, 10]` normalized to unique descending values in `0...1440`.
- Settings Calendar section independently edits Show and Alerts for every descriptor and can open Calendar privacy settings.
- Permission loss clears selected-event context, map highlight, calendar snapshots, and calls `onRemoveCalendarNotifications` for the alerts slice.

- [ ] **Step 1: Extend failing persistence tests**

Test defaults, round-trip, independent Show/Alerts controls, lead validation (`nil`, `-1`, `1441`, duplicate `10`, and unsorted input), and retained preferences for disconnected calendars.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement settings and map-state binding**

Replace `TimezoneMapView`'s private `@AppStorage("mapExpanded")` with a binding owned by `CalendarPresentationState`, which itself persists the preference. Manual toggles while an event is selected cancel auto-restoration.

- [ ] **Step 4: Build the Calendar settings section**

Place it after Appearance. Show muted dot, title, source title, Show checkbox, Alerts checkbox, global alerts toggle, two optional integer fields, and the exact limitation text: `TimeZoner schedules up to 7 days ahead while the app is running or when it next opens.` Alerts remain editable when Show is off.

- [ ] **Step 5: Wire permission-loss cleanup and commit**

Run: `cd app && swift run TimeZonerTests`

```bash
git add app/Sources/Stores/SettingsStore.swift app/Sources/Views/SettingsPopover.swift app/Sources/Views/TimezoneMapView.swift app/Sources/Models/CalendarPresentationState.swift app/Sources/Stores/CalendarStore.swift app/Tests/SettingsStoreTests.swift app/Tests/CalendarStoreTests.swift
git commit -m "feat: add calendar preferences"
```

### Task 8: Notification Reconciliation Engine

**Files:**
- Create: `app/Sources/Models/CalendarNotification.swift`
- Create: `app/Sources/Utilities/CalendarNotificationScheduling.swift`
- Create: `app/Sources/Utilities/UserNotificationCenterAdapter.swift`
- Create: `app/Tests/CalendarNotificationTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: `CalendarNotificationCenter` protocol for authorization, pending TimeZoner request snapshots, add/replace, and removal by identifiers.
- Produces: `CalendarNotificationScheduler.reconcile(now:timeZone:) async throws`, fetching its own seven-day interval and never consuming the UI store's current range.
- Request IDs are exactly `timezoner.event.<occurrence-id>.<lead-minutes>` and `userInfo` includes `occurrenceID`, `title`, and `startTimestamp`.

- [ ] **Step 1: Write failing reconciliation tests**

Cover default 30/10 requests, body `Starts in 30 min · 10:00 BKK`, future-only fire dates, all-day/declined/ended/alert-muted exclusion, hidden-but-alert-enabled inclusion, duplicate lead removal, stale TimeZoner request removal, preservation of non-TimeZoner pending requests, and exact seven-day fetch interval.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement desired-request generation**

Build a complete desired dictionary keyed by request ID. Format local start time at reconciliation time. Remove only pending identifiers prefixed `timezoner.event.` that are absent from desired, then add or replace all desired future requests.

- [ ] **Step 4: Implement the UserNotifications adapter**

Wrap `UNUserNotificationCenter` without exposing its request/content types. Request `[.alert, .sound]` only from an explicit `requestAuthorization()` call made when the user enables alerts.

- [ ] **Step 5: Run tests and commit**

Run: `cd app && swift run TimeZonerTests`

```bash
git add app/Sources/Models/CalendarNotification.swift app/Sources/Utilities/CalendarNotificationScheduling.swift app/Sources/Utilities/UserNotificationCenterAdapter.swift app/Tests/CalendarNotificationTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: reconcile calendar notifications"
```

### Task 9: Notification Routing and Alerts Lifecycle

**Files:**
- Create: `app/Sources/Models/PendingCalendarCommand.swift`
- Create: `app/Sources/App/CalendarNotificationDelegate.swift`
- Create: `app/Tests/PendingCalendarCommandTests.swift`
- Modify: `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Sources/App/CalendarPanelCoordinator.swift`
- Modify: `app/Sources/Models/ReferenceMomentController.swift`
- Modify: `app/Sources/Stores/CalendarStore.swift`
- Modify: `app/Sources/Views/SettingsPopover.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces: queued `PendingCalendarCommand(occurrenceID:title:startDate:)` that survives cold-start ordering in memory until shared stores and panels are ready.
- Notification delegate is installed and retained during `applicationWillFinishLaunching`; foreground presentation returns banner and sound.
- Clicking selects the fresh matching event when available or falls back to the stored absolute timestamp/title, shows the paired panel, and routes through `ReferenceMomentController`.

- [ ] **Step 1: Write failing command-routing tests**

Cover response queued before readiness, exactly-once consumption after readiness, matching-event refresh, missing-event timestamp fallback, hidden/running states, foreground banner+sound policy, permission denial leaving calendar display active, and Calendar revocation removing every pending `timezoner.event.*` request.

- [ ] **Step 2: Run tests and confirm failure**

Run: `cd app && swift run TimeZonerTests`

- [ ] **Step 3: Implement delegate and cold-start queue**

Install the delegate before `applicationDidFinishLaunching`. Parse only TimeZoner event payloads; malformed payloads do nothing. Mark coordinator readiness only after both hosting views and shared stores exist, then consume the queue.

- [ ] **Step 4: Wire explicit alert enablement and recurring reconciliation**

When the global toggle changes false→true, request notification permission; if denied, restore false and expose `Open Notification Settings`. Reconcile after launch authorization resolution, EventKit changes, calendar/alert preference changes, timezone changes, and hourly clock ticks. Turning alerts off removes only `timezoner.event.*` requests.

- [ ] **Step 5: Repeat packaged notification permission stability gate**

Install, grant notifications, schedule a near-future test event through the real calendar data, quit, make a harmless compiled marker change, rebuild/reinstall at the same path, and record persistence/recovery in `docs/verification/calendar-permission-spike-2026-09-24.md` under `Notification authorization`. Restore the marker before commit.

- [ ] **Step 6: Run tests, build, and commit**

Run: `cd app && swift run TimeZonerTests`

Run: `./scripts/build.sh`

```bash
git add app/Sources/Models/PendingCalendarCommand.swift app/Sources/App/CalendarNotificationDelegate.swift app/Sources/App/TimeZonerApp.swift app/Sources/App/CalendarPanelCoordinator.swift app/Sources/Models/ReferenceMomentController.swift app/Sources/Stores/CalendarStore.swift app/Sources/Views/SettingsPopover.swift app/Tests/PendingCalendarCommandTests.swift app/Tests/TimeZonerTests.swift docs/verification/calendar-permission-spike-2026-09-24.md
git commit -m "feat: route calendar alerts"
```

### Task 10: Documentation and End-to-End Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/RELEASE_READINESS.md`
- Modify: `docs/verification/calendar-permission-spike-2026-09-24.md`

**Interfaces:**
- Documents macOS Calendar as the account source, read-only behavior despite full EventKit permission, local attendee handling, optional notification behavior, seven-day/no-background limitation, and actual observed permission stability results.

- [ ] **Step 1: Update product and release documentation**

State that TimeZoner uses accounts configured in macOS Calendar, has no Google sign-in or network calendar client, never writes calendar data, and does not persist event or attendee content. Include the observed Calendar and notification permission outcomes; do not promise persistence beyond the evidence recorded by Tasks 1 and 9.

- [ ] **Step 2: Run the complete automated suite**

Run: `cd app && swift run TimeZonerTests`

Expected: zero failures.

- [ ] **Step 3: Verify package, signing, and plist**

Run: `./scripts/build.sh && codesign --verify --deep --strict app/TimeZoner.app && /usr/libexec/PlistBuddy -c 'Print :NSCalendarsFullAccessUsageDescription' app/TimeZoner.app/Contents/Info.plist`

Expected final line: `TimeZoner reads your calendars to show upcoming events across your saved time zones.`

- [ ] **Step 4: Perform the manual acceptance pass**

Verify two macOS-configured Google accounts; independent mute/hide; Apple Calendar edit refresh; one event across all active cities; Today/3 Days/Week navigation; right/left/popover wing placement; permission revocation; wake/timezone/reopen refresh; hidden-app notifications; notification click while running, hidden, and cold-started; and both-panel focus/Escape behavior. Record each result as pass/fail with macOS version in the verification document.

- [ ] **Step 5: Audit scope and persistence**

Run: `rg -n "EKEventStore|UNUserNotificationCenter" app/Sources`

Expected: EventKit references are confined to the provider/probe and UserNotifications references to the adapter/delegate.

Run: `rg -n "eventTitle|attendee|startDate|endDate" app/Sources/Stores app/Sources/Models | rg "UserDefaults|set\("`

Expected: no event or attendee persistence.

- [ ] **Step 6: Commit documentation**

```bash
git add README.md docs/RELEASE_READINESS.md docs/verification/calendar-permission-spike-2026-09-24.md
git commit -m "docs: document calendar companion behavior"
```
