# TimeZoner Calendar Companion Design

**Status:** Draft for user review

## Goal

Add a read-only macOS Calendar companion that makes upcoming meetings immediately useful across time zones without turning TimeZoner into a calendar-management app.

The defining interaction is event-to-time conversion: selecting a timed calendar event sets TimeZoner's existing reference moment to the event start, so every active city card displays that meeting's local time.

## Product principles

1. TimeZoner remains a timezone tool first. Calendar data supplies useful moments; it does not create a parallel scheduling product.
2. Use the calendar accounts already configured in macOS. There is no Google OAuth, TimeZoner account, server, or network client.
3. Calendar access is read-only by product policy. EventKit requires full calendar permission to read events, but TimeZoner never creates, updates, or deletes calendar data.
4. The normal floating panel remains visually and behaviorally recognizable as TimeZoner.
5. Calendar color is a quiet identifier, not a dominant surface color.
6. Event and attendee data remain on the Mac and are not persisted by TimeZoner.

## Release scope

This release includes:

- macOS Calendar access through EventKit;
- all calendar accounts already available to macOS Calendar, including multiple Google accounts;
- a narrow agenda wing attached to the right or left of the existing panel;
- Today, 3 Days, and Week read-only calendar ranges;
- per-calendar visibility and alert preferences;
- optional TimeZoner-owned local notifications with configurable lead times;
- event selection that updates all active timezone cards;
- permission, empty, loading, and error states;
- automatic refresh while TimeZoner is running.

This release excludes:

- direct Google authentication or Google Calendar API access;
- creating, editing, deleting, accepting, or declining events;
- attendee messaging, conferencing controls, attachments, or event notes;
- background agents, push services, or a TimeZoner server;
- calendar search through the natural-language chat field;
- Raycast calendar integration;
- a month view.

## Delivery slices

Implementation is split into two independently reviewable plans so the calendar value ships without being blocked by notification plumbing:

1. **Calendar Companion Core:** EventKit access, shared application state, attached agenda wing, Today/3 Days/Week views, per-calendar Show preferences, and event-to-timezone selection.
2. **Calendar Alerts:** notification permission, per-calendar Alerts preferences, configurable 30-minute and 10-minute defaults, reconciliation, and notification-click routing.

The core is complete and useful without alerts. The alerts plan depends on the core calendar-provider and preference interfaces and does not redesign the calendar UI.

## Access and activation

The header gains a quiet calendar glyph beside Settings. It has the same visual weight as the existing gear and is not a filled or bordered primary button.

On first activation, TimeZoner explains that it reads events from macOS Calendar and displays them across saved timezones. Continuing calls `EKEventStore.requestFullAccessToEvents()`. TimeZoner does not query the event store before the permission result.

`Show agenda wing` defaults to off for existing and new installations, preventing an unsolicited permission prompt. Activating the header glyph or enabling the setting starts the access explanation; successful permission turns the setting on. After permission exists, the header glyph simply shows or hides the wing without revoking access.

The app adds this exact `Info.plist` value:

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>TimeZoner reads your calendars to show upcoming events across your saved time zones.</string>
```

The current source-built app is not sandboxed, so this release does not add a sandbox entitlement. A future sandboxed distribution must add `com.apple.security.personal-information.calendars` before shipping.

Permission behavior is explicit:

- `.notDetermined`: show the explanation and an Enable Calendar button.
- `.fullAccess`: fetch calendars and events.
- `.denied` or `.restricted`: show a compact unavailable state and a button that opens the Calendar privacy pane in System Settings.
- `.writeOnly`: treat as unavailable because write-only access cannot return events.

TimeZoner never requests notification permission merely because calendar access was enabled. Notification permission is requested only when the user turns on TimeZoner alerts.

## Window model

### Normal timezone mode

The main TimeZoner panel keeps its chat field, active timezone cards, and map. A second narrow `NSPanel`, the agenda wing, appears with a 10-point gap beside it.

The agenda wing is magnetically attached rather than independently movable:

- it moves with the main panel;
- it appears and hides with the main panel;
- its top aligns with the main panel's top;
- it appears on the right when there is room and falls back to the left near the screen edge;
- it uses the same menu-bar-hugging corner behavior, material, shadow, and adaptive theme as the main panel;
- closing or hiding the agenda wing does not disable calendar access.

The wing is approximately 220 points wide. It scrolls vertically when needed and does not increase the main panel width calculation.

### Calendar mode

A small low-contrast expand glyph in the wing, or the `Open week` row at its foot, switches the existing main panel into calendar mode. The agenda wing hides while calendar mode is active.

Calendar mode preserves the drag pill and compact header, replaces timezone cards and the map with a read-only time grid, and exposes a `Today / 3 Days / Week` range picker. Week is the initial range when entering through the expand action; the most recently chosen range is remembered for the current app session.

The grid uses the Mac's current timezone, includes an all-day row, scrolls vertically through hours, and marks the current time when the visible range includes today. Events use a very light tint plus a thin indicator derived from their calendar color.

A quiet `Back to TimeZoner` control restores normal timezone mode and the agenda wing.

## Agenda wing

The wing header displays `Today`, the local date, and the Mac's current timezone abbreviation. All event start and end times in the wing are formatted in `TimeZone.current`, regardless of the event's source calendar timezone.

The Today list contains:

- all-day events in a compact informational row at the top;
- an in-progress timed event, if any;
- timed events for the remainder of the local day;
- past timed events dimmed and collapsed behind a `Earlier` disclosure rather than occupying the default view.

Each timed event row shows, in order:

1. event title;
2. local start and end time;
3. attendee display names, when present, collapsed to `Name, Name + N` after two names;
4. calendar title;
5. a 2-to-3-point muted dot or line derived from the calendar color.

Rows use warm low-contrast dividers and the existing rounded typography. There are no large colored bars, account logos, event-edit controls, or Google branding.

An event without a title uses `Untitled event`. Declined or cancelled events are omitted. Tentative events remain visible with reduced opacity. Events from hidden calendars are not fetched into the presentation model.

All-day rows are informational because they do not identify a precise meeting moment. Selecting an all-day event does not change `TimeState`.

## Event-to-timezone interaction

EventKit supplies each timed event start as an absolute `Date`. Selecting an event performs one state transition:

```swift
timeState.select(date: event.startDate, sourceZone: .current)
```

`TimeState.select(date:sourceZone:)` sets:

- `referenceDate` to the event start date;
- `sourceZoneId` to the supplied timezone identifier;
- `isLive` to `false`.

Every active `ZoneCard` already formats `referenceDate` in its own timezone, so no calendar-specific conversion path is added.

After selection:

- the main panel stays in or returns to normal timezone mode;
- the map collapses to give the event and cards more room;
- a compact context row above the cards shows the event title, local date, local time, and current-timezone abbreviation;
- the selected row in the agenda wing receives a subtle accent treatment;
- every active city card shows the event's local time and date;
- `Now` clears the selected-event context, restores live time, and returns the map to its prior expansion state.

Selecting an event from Today, 3 Days, or Week has the same result. Event selection never changes the user's saved city list.

## Calendar and event model

EventKit objects do not cross the adapter boundary. The library receives immutable value snapshots:

```swift
public struct CalendarDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let color: CalendarColor
}

public struct CalendarEventSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let calendarID: String
    public let calendarTitle: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let attendeeNames: [String]
    public let availability: EventAvailability
    public let participationStatus: EventParticipationStatus
}
```

The occurrence identifier is deterministic for display and notification reconciliation:

```text
<calendarItemIdentifier>|<startDate.timeIntervalSince1970>
```

Including the occurrence start distinguishes recurring-event instances whose EventKit calendar item identifier is shared.

`CalendarColor` stores normalized red, green, blue, and alpha components instead of exposing `CGColor` to tests and views. Views cap the rendered saturation and opacity so bright source colors remain quiet.

`CalendarEventProviding` is the testable boundary around EventKit:

```swift
public protocol CalendarEventProviding: AnyObject {
    var authorizationStatus: CalendarAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func calendars() -> [CalendarDescriptor]
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [CalendarEventSnapshot]
    var changes: AsyncStream<Void> { get }
}
```

`EventKitCalendarProvider` owns one long-lived `EKEventStore`, maps EventKit objects into snapshots, and emits through `changes` whenever `EKEventStoreChanged` fires. A change invalidates fetched EventKit objects; the store refetches the full visible range rather than retaining or mutating stale `EKEvent` instances.

`CalendarStore` is a `@MainActor @Observable` presentation store. It owns authorization state, calendar descriptors, the current fetch range, event snapshots, loading state, and a user-facing error. It filters preferences, sorts all-day items before timed items, and groups events by local calendar day.

The normal agenda fetches from the start of today through the start of the day after tomorrow. It displays today's rows and uses the extra day only to name the next event tomorrow when today is clear. Calendar mode fetches exactly the active Today, 3 Days, or Week interval. The notification scheduler performs its own seven-day fetch so UI range changes do not affect alerts.

## Calendar preferences

Calendar preferences are keyed by EventKit calendar identifier and persisted in `UserDefaults` as Codable values:

```swift
public struct CalendarPreference: Codable, Equatable {
    public var isVisible: Bool
    public var alertsEnabled: Bool
}
```

Newly discovered calendars default to visible with alerts enabled only when global TimeZoner alerts are enabled. Calendars that disappear remain in preferences so a temporarily disconnected account does not lose its choices.

Settings gains a Calendar section after appearance:

- `Show agenda wing` controls presentation and remembers its value;
- each calendar row shows a muted color dot, calendar title, and account/source title;
- `Show` controls whether its events appear in the wing and calendar mode;
- `Alerts` controls whether TimeZoner schedules notifications for it;
- `Alerts` remains independently configurable when `Show` is off, allowing a hidden calendar to notify without appearing in the UI.

This makes “mute” mean disabling Alerts and “hide” mean disabling Show. Neither action changes macOS Calendar.

## TimeZoner notifications

TimeZoner alerts are optional and disabled by default. Enabling them requests `UNUserNotificationCenter` authorization for alerts and sounds. A denied authorization leaves the setting off and presents a compact link to system notification settings.

The default lead times are 30 and 10 minutes. Settings exposes two optional integer lead-time fields constrained to 0 through 1,440 minutes. Empty disables that lead time; duplicate values are deduplicated; values are stored sorted from largest to smallest.

For each eligible timed event, `CalendarNotificationScheduler` creates one local notification per lead time when the calculated fire date is in the future. The notification contains:

- title: the event title;
- body: `Starts in 30 min · 10:00 BKK` using `TimeZone.current` at scheduling time;
- sound: default system sound;
- user info: occurrence identifier and event start timestamp.

Notification request identifiers use:

```text
timezoner.event.<occurrence-id>.<lead-minutes>
```

Scheduling is reconciliation, not append-only behavior:

1. fetch eligible events for the next seven days;
2. calculate the complete desired identifier set;
3. remove TimeZoner event requests no longer desired;
4. add or replace desired future requests;
5. leave pending notifications from other apps untouched.

Reconciliation runs on app launch after permissions resolve, when EventKit reports a store change, when calendar or alert settings change, and once per hour while TimeZoner remains running. Scheduled local notifications remain deliverable when TimeZoner is not running. Because this release has no background agent, events created or changed after the app quits are not reflected until the next launch; Settings states this limitation plainly.

Clicking a TimeZoner notification opens the panel and selects the event start across all active cities. If the event can no longer be fetched, TimeZoner still selects the stored absolute start timestamp and labels the context with the notification title.

All-day events, declined events, hidden-alert calendars, events that have ended, and fire dates already in the past do not generate notifications.

## Shared application state and panel coordination

`AppDelegate` currently creates one `ContentView` whose stores are private `@State` values. Calendar integration requires both panels to observe the same state, so root ownership moves upward:

- `AppDelegate` owns one `TimeState`, one `ZoneStore`, one `CalendarStore`, and one `CalendarPresentationState` for the process lifetime;
- the main `ContentView` receives those objects through its initializer;
- `AgendaView` receives the same calendar and presentation stores plus the shared `TimeState`;
- `CalendarPresentationState` owns `mode`, `range`, `selectedEvent`, and the map-expansion snapshot used when an event temporarily collapses the map;
- `CalendarPanelCoordinator` owns the agenda `NSPanel`, attaches it to the main `FloatingPanel`, performs left/right placement, and responds to main-window move, resize, order, and screen changes.

The existing `TimeState.referenceDate` remains the single absolute moment used by timezone cards and the map.

## Privacy and persistence

TimeZoner persists only:

- whether the agenda wing is shown;
- per-calendar Show and Alerts booleans keyed by calendar identifier;
- the global alerts-enabled boolean;
- notification lead times.

It does not persist event titles, attendee identities, event times, calendar contents, OAuth credentials, or EventKit objects. Pending macOS notification requests necessarily contain their notification title, body, occurrence identifier, and event timestamp until delivered or reconciled.

There is no new network traffic. All calendar reads come from the local EventKit database managed by macOS.

## Error and empty states

- No permission: the wing shows the access explanation or System Settings recovery action.
- No visible calendars: the wing links to the Calendar section in Settings.
- No remaining events today: `Clear for the rest of today` plus the next visible event tomorrow, if one exists.
- EventKit fetch failure: retain the last successful snapshots for the current session, mark them `May be out of date`, and expose Retry.
- Calendar removed: omit its events on the next refetch and retain its preferences.
- Notification permission denied: calendar display continues normally; only TimeZoner alerts are disabled.
- Current timezone changes while the app runs: refetch visible ranges, reformat events, and reconcile notifications using the new `TimeZone.current`.

## Testing

The executable `TimeZonerTests` target remains the automated test entry point. EventKit and `UNUserNotificationCenter` are behind protocols; tests use deterministic fakes and never prompt for system permission.

Automated coverage includes:

- EventKit-to-snapshot mapping, recurring occurrence identifiers, attendee-name fallback, and declined-event filtering;
- local-day range calculations across daylight-saving transitions;
- Today, 3 Days, and Week grouping and sorting;
- calendar Show and Alerts preference persistence and discovery defaults;
- subtle calendar color normalization;
- timed-event selection updating `TimeState`, source timezone, and live state;
- all-day selection leaving `TimeState` unchanged;
- selected-event context and map-collapse state restoration through `Now`;
- notification lead-time validation and deduplication;
- desired notification request generation, stale-request removal, and seven-day reconciliation;
- notification response fallback when an event can no longer be fetched;
- agenda placement on the right and left within a screen's visible frame.

Manual verification covers the real system boundaries:

1. grant and deny Calendar permission;
2. display calendars from two macOS-configured Google accounts;
3. mute and hide separate calendars;
4. modify an event in Apple Calendar and observe TimeZoner refresh;
5. select an event and verify all active city cards show the same instant;
6. enter and leave Today, 3 Days, and Week modes;
7. move the main panel between screen edges and displays;
8. grant and deny notifications;
9. receive 30-minute and 10-minute notifications while TimeZoner is hidden;
10. click a notification and verify the event instant appears across active cities;
11. build, sign, install, relaunch, and repeat permission-sensitive flows using the packaged app.

## Distribution and documentation

The implementation updates the README and release-readiness documentation with:

- macOS Calendar as the account source;
- the read-only/full-permission distinction;
- attendee data staying local;
- notification behavior and its no-background-agent limitation;
- the exact build/install test for Calendar permission stability under the app's ad-hoc signature.

No deployment, release, tag, Homebrew formula update, or external publication is part of this work.
