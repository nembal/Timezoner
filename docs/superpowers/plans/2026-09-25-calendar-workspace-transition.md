# Calendar Workspace and Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give TimeZoner and its calendar two persistent, consistently aligned floating panels that exchange size smoothly while selected events remain visible beside their city times.

**Architecture:** Keep the existing main `NSPanel` as normal TimeZoner/compact city rail and the existing agenda `NSPanel` as agenda/full calendar. Put frame calculation and transition sequencing in testable library types, with `CalendarPanelCoordinator` owning native animation, focus, and restoration. Share one chrome component and settings anchor implementation; retain the current EventKit, CalendarStore, and ReferenceMomentController graph.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Observation, EventKit, Swift Package Manager, executable `TimeZonerTests`, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-09-25-calendar-workspace-transition-design.md`

## Global Constraints

- macOS 14+; use SwiftUI, AppKit, Swift Package Manager, and `@Observable`.
- Zero third-party dependencies, zero direct network clients, no Google OAuth, and no TimeZoner account.
- Calendar reads come only from the local EventKit database; never create, update, delete, accept, or decline events.
- Do not persist event titles, attendee identities, event times, calendar contents, OAuth credentials, or EventKit objects.
- `TimeState.referenceDate` remains the single absolute moment; all reference-moment mutations use `ReferenceMomentController`.
- Calendar ranges and labels use `CalendarStore.localCalendar` and its injected clock, with production `TimeZone.current` behavior.
- Newly unset agenda visibility defaults to on; an explicitly saved off preference stays off. Alerts remain opt-in and unchanged.
- Rendering the agenda or access explanation never requests permission or fetches events without full Calendar access.
- Both workspace panels remain visible; changing focus never hides either panel or dims their text.
- Use the executable `TimeZonerTests` target; automated tests use fakes and never prompt for system permission.
- No event editor, new account system, month view, background agent, new notification behavior, push, release, or external publication.

## Review Focus

1. Repeated expand/return and Escape during animation must not let a stale completion reveal, focus, or resize hidden panels; pin with `runCalendarWorkspaceTransitionTests()` in Task 6.
2. A narrow screen, negative display origin, or removed display must keep both workspace panels reachable and restore the normal frame sensibly; pin with `runCalendarWorkspaceLayoutTests()` in Task 2 and pair-drag tests in Task 5.
3. Fresh defaults, an explicitly hidden agenda, and Calendar access loss/grant must retain user intent without unsolicited permission or fetch calls; pin with settings/policy/provider-fake tests in Task 1.
4. Focus transfer into either panel or settings/event details must not dismiss the pair, and settings must have one correct anchor; pin with owner-binding and panel fake tests in Tasks 3 and 5.
5. Zero/many cities, selected/all-day events, notification activation, and city-adding deep links must keep one reference moment and avoid obsolete frame restoration; pin with rail/activation tests in Task 4 and routing/restoration tests in Task 5.

---

## Starting point and execution boundaries

Read the spec and this plan together. The current branch is `codex/calendar-companion` in `/Users/team/dev/worktrees/Timezoner/codex-calendar-companion`; preserve all pre-existing work. Check current status before beginning. Use Worktrunk for any additional isolated coding workspace as required by repository policy; do not create a duplicate checkout around an app-managed worktree. This plan-writing task does not authorize implementation or installation yet.

At plan creation the worktree includes the icon-control implementation (`6ba5746`) and current Calendar Companion tests. Existing docs may report 661 tests; that number is historical and must not be copied as a new execution result.

The user previously chose subagent-driven implementation with Terra xhigh builders. Preserve that choice for execution after plan review. The Astra request applies to this planning pass; it does not silently change the build/review model preference.

Run commands from the feature worktree unless a step says otherwise. The full executable test suite is the supported entry point; it has no single-test filter. Use `./scripts/build.sh` for the packaged app because it applies the CLT/SPM toolchain wrapper. Do not reset Calendar permissions as a testing shortcut.

## File map

| File | Responsibility |
| --- | --- |
| `app/Sources/Models/CalendarWorkspaceState.swift` (new) | Panel identity, visible/read/settings policy, compact context/card data, transition gate/timing |
| `app/Sources/Models/CalendarWorkspaceLayout.swift` (new) | Shared metrics, pair geometry, normal snapshot/restoration |
| `app/Sources/Views/CalendarPanelChrome.swift` (new) | Fixed drag/nav/content slots and icon button styling |
| `app/Sources/Views/CalendarSettingsButton.swift` (new) | Single reusable settings anchor with destination-aware binding |
| `app/Sources/Views/TimeZonerRailView.swift` (new) | Read-only vertical cards, fixed context slot, Now/expand nav |
| `app/Sources/Views/CalendarWorkspaceToolbar.swift` (new) | Full/compact range navigation plus settings slot |
| `app/Sources/Views/CalendarPanelRootView.swift` (new) | Agenda versus full-calendar composition in the calendar window |
| `app/Sources/Models/CalendarPresentationState.swift` | Shared focus/transition values and paired-panel policies; retain range ownership |
| `app/Sources/Models/CalendarRange.swift` | Replace calendar/back glyph metadata with two expand controls |
| `app/Sources/Stores/SettingsStore.swift` | Default-on only for unset agenda preference |
| `app/Sources/Views/ContentView.swift` | Normal TimeZoner/rail composition and normal-only shortcuts |
| `app/Sources/Views/AgendaView.swift` | Shared chrome and expand control; existing event rows remain |
| `app/Sources/Views/CalendarModeView.swift` | Shared chrome/toolbar, settings slot, selection without returning |
| `app/Sources/Views/CalendarTimeGrid.swift` | One horizontal scroll container for narrow full-grid presentation |
| `app/Sources/Views/ChatField.swift` | Fixed nav height and cancellable/explicit focus behavior |
| `app/Sources/Views/DragHandle.swift` | Fixed shared strip height and temporary drag disabling |
| `app/Sources/App/CalendarPanelCoordinator.swift` | Persistent panels, frame snapshots, synchronized transition, focus/restoration |
| `app/Sources/App/FloatingPanel.swift` | Key-window notification and suppression of normal-origin persistence in workspace |
| `app/Sources/App/TimeZonerApp.swift` | Composition, access defaults, workspace-aware notification/deep-link integration |
| `app/Tests/CalendarWorkspaceStateTests.swift` (new) | Policy, rail values, settings owner, activation behavior |
| `app/Tests/CalendarWorkspaceLayoutTests.swift` (new) | Pure geometry and restoration |
| `app/Tests/CalendarWorkspaceTransitionTests.swift` (new) | Motion timing, coalescing, stale-callback rejection |
| Existing settings/panel/presentation/range/store/deep-link/notification tests | Real call-path regression coverage |
| `app/Tests/TimeZonerTests.swift` | Register the three new suites |
| `docs/verification/calendar-workspace-transition-2026-09-25.md` (new), `README.md` | Observed native verification and user-facing behavior |

Do not split unrelated provider or notification files. `CalendarPresentationState.swift` already contains the panel protocols; extend those seams rather than inventing a second app controller.

### Task 1: Default-visible agenda with permission-safe intent

**Files:**
- Create: `app/Sources/Models/CalendarWorkspaceState.swift`
- Create: `app/Tests/CalendarWorkspaceStateTests.swift`
- Modify: `app/Sources/Stores/SettingsStore.swift` (`showAgendaWing` initialization)
- Modify: `app/Sources/Models/CalendarPresentationState.swift` (`CalendarPermissionLossCoordinator`)
- Modify: `app/Sources/App/TimeZonerApp.swift` (`refreshPersistedAgendaIfNeeded`, `setAgendaWingRequested`)
- Modify: `app/Tests/SettingsStoreTests.swift`, `app/Tests/CalendarStoreTests.swift`, `app/Tests/CalendarPresentationStateTests.swift`, `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Consumes existing `CalendarDestination`, `CalendarAuthorizationStatus`, `SettingsStore`, and `CalendarStore.refreshPresentationInterval()`.
- Produces `CalendarPanelIdentity: Equatable, Sendable` with `.timezoner` and `.calendar`.
- Produces `CalendarWorkspacePolicy.calendarVisible(destination:showAgenda:) -> Bool`, `mayReadEvents(status:) -> Bool`, `settingsOwner(destination:) -> CalendarPanelIdentity`.
- Permission loss clears private calendar content, but does not write `showAgendaWing` or change `destination`.

- [ ] **Step 1: Add failing defaults and policy tests**

Change the existing default assertion in `SettingsStoreTests` to expect `true`. Add this explicit false-preservation block using its existing `keys` and `defaults`:

```swift
defaults.set(false, forKey: keys.showAgendaWing)
let hidden = SettingsStore(userDefaults: defaults, keys: keys)
expectTrueS(!hidden.showAgendaWing, "explicit hidden preference survives the new default")
defaults.removeObject(forKey: keys.showAgendaWing)
```

Create the shared assertion helper and first suite. Register `runCalendarWorkspaceStateTests()` in `TimeZonerTests.main()` after presentation tests:

```swift
import Foundation
import TimeZonerLib

func workspaceExpect(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition { testsPassed += 1 }
    else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label)")
    }
}

@MainActor
func runCalendarWorkspaceStateTests() {
    workspaceExpect(CalendarWorkspacePolicy.calendarVisible(
        destination: .timezoner, showAgenda: true), "normal default shows agenda")
    workspaceExpect(!CalendarWorkspacePolicy.calendarVisible(
        destination: .timezoner, showAgenda: false), "normal explicit hide works")
    workspaceExpect(CalendarWorkspacePolicy.calendarVisible(
        destination: .calendar, showAgenda: false), "workspace retains full calendar")
    for status in [CalendarAuthorizationStatus.notDetermined, .denied, .restricted, .writeOnly] {
        workspaceExpect(!CalendarWorkspacePolicy.mayReadEvents(status: status),
                        "unavailable access never permits a read")
    }
    workspaceExpect(CalendarWorkspacePolicy.mayReadEvents(status: .fullAccess),
                    "full access permits automatic refresh")
    workspaceExpect(CalendarWorkspacePolicy.settingsOwner(destination: .timezoner) == .timezoner,
                    "normal settings belongs to main")
    workspaceExpect(CalendarWorkspacePolicy.settingsOwner(destination: .calendar) == .calendar,
                    "workspace settings belongs to calendar")
}
```

- [ ] **Step 2: Run the failing test suite**

Run: `cd app && swift run TimeZonerTests`

Expected: missing `CalendarWorkspacePolicy` compilation errors; after adding the type, the new default assertion fails until the initialization changes.

- [ ] **Step 3: Implement the policy and unset default**

Create the model with this code:

```swift
import Foundation

public enum CalendarPanelIdentity: Equatable, Sendable {
    case timezoner, calendar
}

public enum CalendarWorkspacePolicy {
    public static func calendarVisible(destination: CalendarDestination, showAgenda: Bool) -> Bool {
        destination == .calendar || showAgenda
    }

    public static func mayReadEvents(status: CalendarAuthorizationStatus) -> Bool {
        status == .fullAccess
    }

    public static func settingsOwner(destination: CalendarDestination) -> CalendarPanelIdentity {
        destination == .calendar ? .calendar : .timezoner
    }
}
```

Change only the unset-preference branch to `self.showAgendaWing = true`. Remove `presentation.showAgendaWing = false` from `CalendarPermissionLossCoordinator.handle`. Keep clearing event/details and presenting recovery. Replace the two AppDelegate methods with:

```swift
private func refreshPersistedAgendaIfNeeded() {
    guard presentation.showAgendaWing else { return }
    guard CalendarWorkspacePolicy.mayReadEvents(status: calendarStore.authorizationStatus) else {
        return
    }
    calendarStore.refreshPresentationInterval()
}

private func setAgendaWingRequested(_ requested: Bool) {
    presentation.showAgendaWing = requested
    presentation.dismissAccessDestination()
    if requested && CalendarWorkspacePolicy.mayReadEvents(status: calendarStore.authorizationStatus) {
        calendarStore.refreshPresentationInterval()
    }
    panelCoordinator?.syncAgendaVisibility()
}
```

Keep `CalendarAgendaWingRequest` compatibility until all existing callers/tests are audited; the AppDelegate now uses visible access content rather than hiding the panel. Do not call `requestAccess()` here.

- [ ] **Step 4: Pin revocation and no-implicit-request behavior to real state/store paths**

Append to the workspace state suite:

```swift
let suite = "WorkspacePermission.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let settings = SettingsStore(userDefaults: defaults)
let presentation = CalendarPresentationState(settings: settings, defaults: defaults)
let reference = ReferenceMomentController(timeState: TimeState(), presentation: presentation)
presentation.enterCalendar(now: Date(timeIntervalSince1970: 1_750_000_000), calendar: .current)
CalendarPermissionLossCoordinator.handle(referenceMoment: reference, presentation: presentation)
workspaceExpect(presentation.destination == .calendar, "revocation retains the workspace")
workspaceExpect(presentation.showAgendaWing, "revocation preserves visibility intent")
workspaceExpect(presentation.accessDestination == .recovery, "revocation exposes recovery")
```

In `CalendarStoreTests`, add `private(set) var accessRequestCount = 0` to the existing fake and increment it at the start of `requestAccess()`. Add a test block inside the existing async suite using its existing deterministic signal helper to construct the store:

```swift
let deniedProvider = CalendarStoreProviderFake(authorizationStatus: .denied)
let deniedSignals = CalendarStoreClockSignals()
let deniedClock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: deniedSignals)
let deniedStore = CalendarStore(provider: deniedProvider, clock: deniedClock)
deniedStore.refreshPresentationInterval()
await Task.yield()
workspaceExpect(deniedProvider.accessRequestCount == 0, "visible recovery cannot request permission")
workspaceExpect(deniedProvider.eventRequests.isEmpty, "denied calendar cannot fetch events")
```

Update earlier assertions that required permission loss to set `showAgendaWing` false; preserve their private-data cleanup assertions. Existing explicit-grant/refresh tests remain mandatory.

- [ ] **Step 5: Run tests and commit this behavior**

Run: `cd app && swift run TimeZonerTests`

Expected: all tests pass; no system prompt. Then:

```bash
git add app/Sources/Models/CalendarWorkspaceState.swift app/Sources/Stores/SettingsStore.swift app/Sources/Models/CalendarPresentationState.swift app/Sources/App/TimeZonerApp.swift app/Tests/CalendarWorkspaceStateTests.swift app/Tests/SettingsStoreTests.swift app/Tests/CalendarStoreTests.swift app/Tests/CalendarPresentationStateTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: show calendar agenda by default safely"
```

### Task 2: Shared metrics and deterministic two-panel geometry

**Files:**
- Create: `app/Sources/Models/CalendarWorkspaceLayout.swift`
- Create: `app/Tests/CalendarWorkspaceLayoutTests.swift`
- Modify: `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Consumes existing `AgendaPlacement`, `AgendaPlacementCalculator`, and `CalendarPanelFrameCalculator.restoredNormalFrame(_:visibleFrame:screenDidChange:)`.
- Produces `CalendarPanelMetrics`, `CalendarWorkspaceFrames(main:calendar:arrangement:)`, `CalendarNormalLayoutSnapshot`, `CalendarWorkspaceRestoration`, and the three calculator functions shown below.
- Frame calculations use AppKit's bottom-left coordinate convention and injected `CGRect`s only; no `NSScreen`, `Date()`, or city store reads.

- [ ] **Step 1: Write the failing geometry suite and register it**

```swift
import Foundation
import TimeZonerLib

func runCalendarWorkspaceLayoutTests() {
    let screen = CGRect(x: -1440, y: 40, width: 1440, height: 860)
    let main = CGRect(x: -1120, y: 240, width: 700, height: 580)
    let agenda = CGRect(x: -410, y: 240, width: 220, height: 580)
    let frames = CalendarWorkspaceLayout.calculate(
        main: main, agenda: agenda, placement: .right, visibleFrame: screen)
    workspaceExpect(frames.main.width == 240 && frames.calendar.width == 760,
                    "preferred rail and calendar widths")
    workspaceExpect(frames.calendar.maxX == agenda.maxX, "calendar retains right anchor")
    workspaceExpect(frames.main.maxY == main.maxY && frames.calendar.maxY == main.maxY,
                    "both panels retain the top anchor")
    workspaceExpect(frames.calendar.minX - frames.main.maxX == 10, "fixed gap")
    workspaceExpect(screen.contains(frames.main) && screen.contains(frames.calendar),
                    "negative display coordinates stay contained")

    for size in [CGSize(width: 800, height: 600), CGSize(width: 570, height: 400),
                 CGSize(width: 500, height: 700), CGSize(width: 500, height: 300)] {
        let visible = CGRect(origin: CGPoint(x: 90, y: -800), size: size)
        let result = CalendarWorkspaceLayout.calculate(
            main: main, agenda: nil, placement: .popover, visibleFrame: visible)
        workspaceExpect(visible.contains(result.main) && visible.contains(result.calendar),
                        "small-screen frames remain visible")
        workspaceExpect(!result.main.intersects(result.calendar), "panels do not overlap")
        workspaceExpect(result.arrangement == (size.width >= 570 ? .sideBySide : .stacked),
                        "narrow fallback is explicit")
    }

    let snapshot = CalendarNormalLayoutSnapshot(main: main, agenda: agenda,
        placement: .right, screenID: "left", visibleFrame: screen, cityCount: 4)
    let restored = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: screen,
        screenID: "left", cityCount: 4)
    workspaceExpect(restored.main == main && restored.agenda.frame == agenda,
                    "unchanged screen and cities restore exactly")
    let added = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: screen,
        screenID: "left", cityCount: 8)
    workspaceExpect(added.main.width == min(CalendarPanelMetrics.normalWidth(cityCount: 8), screen.width),
                    "city additions cannot restore obsolete width")
    let removedDisplay = CGRect(x: 0, y: 0, width: 900, height: 600)
    let moved = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: removedDisplay,
        screenID: "built-in", cityCount: 4)
    workspaceExpect(removedDisplay.contains(moved.main), "missing display reclamps main")
}
```

Register `runCalendarWorkspaceLayoutTests()` after the state suite. Run: `cd app && swift run TimeZonerTests`. Expected: undefined layout types.

- [ ] **Step 2: Implement metrics and data contracts**

```swift
import Foundation

public enum CalendarPanelMetrics {
    public static let horizontalInset: CGFloat = 20
    public static let dragHeight: CGFloat = 20
    public static let topInset: CGFloat = 6
    public static let navHeight: CGFloat = 40
    public static let contentGap: CGFloat = 12
    public static let bottomInset: CGFloat = 16
    public static let iconTarget: CGFloat = 28
    public static let cornerRadius: CGFloat = 12
    public static let gap: CGFloat = 10
    public static let railWidth: CGFloat = 240
    public static let calendarWidth: CGFloat = 760
    public static let preferredHeight: CGFloat = 580
    public static let narrowThreshold: CGFloat = 570
    public static let compactToolbarThreshold: CGFloat = 600
    public static func normalWidth(cityCount: Int) -> CGFloat {
        let count = CGFloat(max(cityCount, 2))
        return count * 155 + max(count - 1, 0) * 36 + 40
    }
}

public struct CalendarWorkspaceFrames: Equatable, Sendable {
    public enum Arrangement: Equatable, Sendable { case sideBySide, stacked }
    public let main: CGRect
    public let calendar: CGRect
    public let arrangement: Arrangement
    public init(main: CGRect, calendar: CGRect, arrangement: Arrangement) {
        self.main = main; self.calendar = calendar; self.arrangement = arrangement
    }
}

public struct CalendarNormalLayoutSnapshot: Equatable, Sendable {
    public let main: CGRect
    public let agenda: CGRect?
    public let placement: AgendaPlacement
    public let screenID: String?
    public let visibleFrame: CGRect
    public let cityCount: Int
    public init(main: CGRect, agenda: CGRect?, placement: AgendaPlacement,
                screenID: String?, visibleFrame: CGRect, cityCount: Int) {
        self.main = main; self.agenda = agenda; self.placement = placement
        self.screenID = screenID; self.visibleFrame = visibleFrame; self.cityCount = cityCount
    }
}

public struct CalendarWorkspaceRestoration: Equatable, Sendable {
    public let main: CGRect
    public let agenda: AgendaPlacementResult
    public init(main: CGRect, agenda: AgendaPlacementResult) {
        self.main = main; self.agenda = agenda
    }
}
```

- [ ] **Step 3: Implement workspace geometry and restoration**

Append the following implementation. An invalid visible frame uses the main frame's positive bounds as a deterministic fallback; production must still prefer an actual connected screen.

```swift
public enum CalendarWorkspaceLayout {
    public static func calculate(main: CGRect, agenda: CGRect?, placement: AgendaPlacement,
                                 visibleFrame: CGRect) -> CalendarWorkspaceFrames {
        let visible = visibleFrame.width > 0 && visibleFrame.height > 0 ? visibleFrame
            : CGRect(origin: main.origin, size: CGSize(width: max(main.width, 570), height: max(main.height, 300)))
        let height = min(CalendarPanelMetrics.preferredHeight, visible.height)
        let top = min(max(main.maxY, visible.minY + height), visible.maxY)
        if visible.width >= CalendarPanelMetrics.narrowThreshold {
            let rail = min(CalendarPanelMetrics.railWidth, max(200, visible.width - 370))
            let calendar = min(CalendarPanelMetrics.calendarWidth, visible.width - rail - 10)
            let width = rail + 10 + calendar
            let desiredRight = placement == .right ? (agenda?.maxX ?? main.maxX) : main.maxX
            let right = min(max(desiredRight, visible.minX + width), visible.maxX)
            let left = right - width
            return CalendarWorkspaceFrames(
                main: CGRect(x: left, y: top - height, width: rail, height: height),
                calendar: CGRect(x: left + rail + 10, y: top - height, width: calendar, height: height),
                arrangement: .sideBySide)
        }
        let gap = min(10, visible.height / 10)
        let railHeight = min(180, (visible.height - gap) * 0.35)
        let calendarHeight = visible.height - railHeight - gap
        return CalendarWorkspaceFrames(
            main: CGRect(x: visible.minX, y: visible.maxY - railHeight,
                         width: visible.width, height: railHeight),
            calendar: CGRect(x: visible.minX, y: visible.minY,
                             width: visible.width, height: calendarHeight),
            arrangement: .stacked)
    }

    public static func restore(_ snapshot: CalendarNormalLayoutSnapshot, visibleFrame: CGRect,
                               screenID: String?, cityCount: Int) -> CalendarWorkspaceRestoration {
        let screenChanged = snapshot.screenID != screenID || snapshot.visibleFrame != visibleFrame
        let citiesChanged = snapshot.cityCount != cityCount
        var main = snapshot.main
        if citiesChanged {
            let width = CalendarPanelMetrics.normalWidth(cityCount: cityCount)
            main = CGRect(x: main.midX - width / 2, y: main.minY, width: width, height: main.height)
        }
        main = CalendarPanelFrameCalculator.restoredNormalFrame(
            main, visibleFrame: visibleFrame, screenDidChange: screenChanged || citiesChanged)
        if !screenChanged && !citiesChanged,
           let agenda = snapshot.agenda, visibleFrame.contains(agenda),
           snapshot.placement != .popover {
            return CalendarWorkspaceRestoration(main: main,
                agenda: AgendaPlacementResult(location: snapshot.placement, frame: agenda))
        }
        return CalendarWorkspaceRestoration(main: main,
            agenda: AgendaPlacementCalculator.calculate(mainFrame: main, visibleFrame: visibleFrame,
                wingSize: CGSize(width: AgendaPlacementCalculator.wingWidth, height: 580)))
    }

    public static func translated(_ frames: CalendarWorkspaceFrames, by delta: CGSize,
                                  visibleFrame: CGRect) -> CalendarWorkspaceFrames {
        let union = frames.main.union(frames.calendar)
        let dx = min(max(delta.width, visibleFrame.minX - union.minX), visibleFrame.maxX - union.maxX)
        let dy = min(max(delta.height, visibleFrame.minY - union.minY), visibleFrame.maxY - union.maxY)
        return CalendarWorkspaceFrames(main: frames.main.offsetBy(dx: dx, dy: dy),
            calendar: frames.calendar.offsetBy(dx: dx, dy: dy), arrangement: frames.arrangement)
    }
}
```

- [ ] **Step 4: Add display/drag invariants, run tests, and commit**

Append this test to the layout suite:

```swift
let dragged = CalendarWorkspaceLayout.translated(frames,
    by: CGSize(width: 10_000, height: -10_000), visibleFrame: screen)
workspaceExpect(screen.contains(dragged.main) && screen.contains(dragged.calendar),
                "pair drag clamps as one object")
workspaceExpect(dragged.calendar.minX - dragged.main.maxX == 10,
                "drag cannot detach the panels")
workspaceExpect(dragged.calendar.maxY == dragged.main.maxY, "drag preserves top alignment")
```

Run: `cd app && swift run TimeZonerTests`. Expected: all tests pass.

```bash
git add app/Sources/Models/CalendarWorkspaceLayout.swift app/Tests/CalendarWorkspaceLayoutTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: define calendar workspace geometry"
```

### Task 3: Shared chrome and single-owner settings

**Files:**
- Create: `app/Sources/Views/CalendarPanelChrome.swift`
- Create: `app/Sources/Views/CalendarSettingsButton.swift`
- Modify: `app/Sources/Models/CalendarWorkspaceState.swift`, `app/Sources/Models/CalendarPresentationState.swift`
- Modify: `app/Sources/Views/DragHandle.swift`, `app/Sources/Views/ChatField.swift`
- Modify: `app/Tests/CalendarWorkspaceStateTests.swift`

**Interfaces:**
- Consumes `CalendarPanelMetrics` and `CalendarWorkspacePolicy.settingsOwner(destination:)`.
- Produces `CalendarPanelChrome<Header: View, Content: View>(isHugging:isFocused:contentOpacity:contentOffset:interactionEnabled:header:content:)` and `CalendarToolbarIcon(systemName:label:hint:action:)`.
- Produces `CalendarSettingsButton<Content: View>(owner:presentation:onActivate:onOwnedPopoverChanged:content:)` and `CalendarSettingsOwnership.isPresented(owner:presentation:)` / `setPresented(_:owner:presentation:onOwnedPopoverChanged:)`.
- Adds `CalendarPresentationState.focusedPanel: CalendarPanelIdentity?`, initially `nil`. Only native key-window notifications set it.

- [ ] **Step 1: Write a settings-anchor regression before the component**

Append within `runCalendarWorkspaceStateTests()`, where its isolated `presentation` is already in `.calendar`:

```swift
var owned = false
CalendarSettingsOwnership.setPresented(true, owner: .calendar,
    presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
workspaceExpect(owned && CalendarSettingsOwnership.isPresented(owner: .calendar, presentation: presentation),
                "calendar settings retains the pair")
workspaceExpect(!CalendarSettingsOwnership.isPresented(owner: .timezoner, presentation: presentation),
                "only one settings anchor can present")
CalendarSettingsOwnership.setPresented(false, owner: .timezoner,
    presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
workspaceExpect(presentation.isSettingsPresented && owned,
                "stale inactive anchor cannot close the active settings popover")
CalendarSettingsOwnership.setPresented(false, owner: .calendar,
    presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
workspaceExpect(!presentation.isSettingsPresented && !owned, "active owner releases popover protection")
```

Run: `cd app && swift run TimeZonerTests`. Expected: undefined `CalendarSettingsOwnership`.

- [ ] **Step 2: Implement settings ownership and focused-panel state**

Add `public var focusedPanel: CalendarPanelIdentity?` to `CalendarPresentationState`. Append this helper to the workspace state file:

```swift
@MainActor
public enum CalendarSettingsOwnership {
    public static func isPresented(owner: CalendarPanelIdentity,
                                   presentation: CalendarPresentationState) -> Bool {
        CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) == owner
            && presentation.isSettingsPresented
    }
    public static func setPresented(_ value: Bool, owner: CalendarPanelIdentity,
                                    presentation: CalendarPresentationState,
                                    onOwnedPopoverChanged: (Bool) -> Void) {
        guard CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) == owner else { return }
        presentation.isSettingsPresented = value
        onOwnedPopoverChanged(presentation.hasOwnedPopover)
    }
}
```

- [ ] **Step 3: Implement common panel and control chrome**

Create `CalendarPanelChrome.swift`:

```swift
import SwiftUI

public struct CalendarPanelChrome<Header: View, Content: View>: View {
    let isHugging: Bool
    let isFocused: Bool
    let contentOpacity: Double
    let contentOffset: CGFloat
    let interactionEnabled: Bool
    let header: Header
    let content: Content

    public init(isHugging: Bool, isFocused: Bool, contentOpacity: Double = 1,
                contentOffset: CGFloat = 0, interactionEnabled: Bool = true,
                @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.isHugging = isHugging; self.isFocused = isFocused
        self.contentOpacity = contentOpacity; self.contentOffset = contentOffset
        self.interactionEnabled = interactionEnabled
        self.header = header(); self.content = content()
    }

    public var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isHugging ? 0 : CalendarPanelMetrics.cornerRadius,
            bottomLeadingRadius: CalendarPanelMetrics.cornerRadius,
            bottomTrailingRadius: CalendarPanelMetrics.cornerRadius,
            topTrailingRadius: isHugging ? 0 : CalendarPanelMetrics.cornerRadius,
            style: .continuous)
        VStack(spacing: 0) {
            DragHandle(showPill: true, isHugging: isHugging)
                .allowsHitTesting(interactionEnabled)
            VStack(spacing: CalendarPanelMetrics.contentGap) {
                header.frame(height: CalendarPanelMetrics.navHeight)
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .opacity(contentOpacity)
            .offset(x: contentOffset)
            .allowsHitTesting(interactionEnabled)
            .accessibilityHidden(!interactionEnabled)
            .padding(.horizontal, CalendarPanelMetrics.horizontalInset)
            .padding(.top, CalendarPanelMetrics.topInset)
            .padding(.bottom, CalendarPanelMetrics.bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .clipShape(shape)
        .overlay(shape.strokeBorder(isFocused ? Theme.accent.opacity(0.22) : Theme.border, lineWidth: 1))
    }
}

public struct CalendarToolbarIcon: View {
    let systemName: String
    let label: String
    let hint: String
    let action: () -> Void
    public init(systemName: String, label: String, hint: String, action: @escaping () -> Void) {
        self.systemName = systemName; self.label = label; self.hint = hint; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: CalendarPanelMetrics.iconTarget, height: CalendarPanelMetrics.iconTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textSecondary)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .help(label)
    }
}
```

Change `DragHandle.body`'s frame height to `CalendarPanelMetrics.dragHeight`; retain its actual manual AppKit drag mechanism. In `ChatField`, replace vertical padding with `.frame(height: CalendarPanelMetrics.navHeight)` and preserve its horizontal padding/background. A font or padding constant is verified by native rendering, not a test that merely compares that constant with itself.

- [ ] **Step 4: Implement the reusable settings anchor**

Create `CalendarSettingsButton.swift`:

```swift
import SwiftUI

public struct CalendarSettingsButton<Content: View>: View {
    let owner: CalendarPanelIdentity
    let presentation: CalendarPresentationState
    let onActivate: () -> Void
    let onOwnedPopoverChanged: (Bool) -> Void
    let content: Content

    public init(owner: CalendarPanelIdentity, presentation: CalendarPresentationState,
                onActivate: @escaping () -> Void,
                onOwnedPopoverChanged: @escaping (Bool) -> Void,
                @ViewBuilder content: () -> Content) {
        self.owner = owner; self.presentation = presentation
        self.onActivate = onActivate; self.onOwnedPopoverChanged = onOwnedPopoverChanged
        self.content = content()
    }

    public var body: some View {
        CalendarToolbarIcon(systemName: "gearshape", label: "Settings (⌘,)",
                            hint: "Opens TimeZoner settings.", action: onActivate)
            .popover(isPresented: Binding(
                get: { CalendarSettingsOwnership.isPresented(owner: owner, presentation: presentation) },
                set: { CalendarSettingsOwnership.setPresented($0, owner: owner,
                    presentation: presentation, onOwnedPopoverChanged: onOwnedPopoverChanged) }
            ), arrowEdge: .bottom) { content }
    }
}
```

The `SettingsPopover` supplied to this component remains the existing one, initialized with existing shared objects. Do not create another SettingsStore or notification lifecycle.

- [ ] **Step 5: Test, package-build, and commit**

Run: `cd app && swift run TimeZonerTests`; then `./scripts/build.sh` from the worktree root. Expected: all tests pass; app compiles. Native alignment is checked after the components are adopted in Task 4.

```bash
git add app/Sources/Models/CalendarWorkspaceState.swift app/Sources/Models/CalendarPresentationState.swift app/Sources/Views/CalendarPanelChrome.swift app/Sources/Views/CalendarSettingsButton.swift app/Sources/Views/DragHandle.swift app/Sources/Views/ChatField.swift app/Tests/CalendarWorkspaceStateTests.swift
git commit -m "refactor: share calendar panel chrome and settings ownership"
```

### Task 4: Compose the compact rail and calendar controls

**Files:**
- Create: `app/Sources/Views/TimeZonerRailView.swift`, `app/Sources/Views/CalendarWorkspaceToolbar.swift`, `app/Sources/Views/CalendarPanelRootView.swift`
- Modify: `app/Sources/Models/CalendarWorkspaceState.swift`, `app/Sources/Models/CalendarRange.swift`
- Modify: `app/Sources/Views/ContentView.swift`, `app/Sources/Views/AgendaView.swift`, `app/Sources/Views/CalendarModeView.swift`, `app/Sources/Views/CalendarTimeGrid.swift`, `app/Sources/Views/ChatField.swift`
- Modify: `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Tests/CalendarWorkspaceStateTests.swift`, `app/Tests/CalendarRangeTests.swift`, `app/Tests/CalendarPresentationStateTests.swift`

**Interfaces:**
- Produces `CalendarRailCardPresentation(zone:date:)` with `title`, `time`, `date`, `offset`, `accessibilityLabel` strings.
- Produces `CalendarWorkspaceEventActivation.select(_:referenceMoment:)` which selects timed events without navigating.
- Produces `TimeZonerRailView(zones:referenceMoment:presentation:onExpand:)` and `CalendarWorkspaceToolbar(calendarStore:presentation:settingsButton:)`.
- Changes `CalendarModeView` initializer: remove `onReturnToTimeZoner`; add `settingsButton: CalendarSettingsButton<SettingsPopover>`. Other parameters remain.
- Produces `CalendarPanelRootView(presentation:agenda:calendar:)` with concrete `AgendaView` and `CalendarModeView` values.
- Rename icon metadata cases to `.expandCalendar` and `.expandTimeZoner`; actions are unchanged until the native routing task.

- [ ] **Step 1: Write event-activation and zero/many-city value tests**

Append inside `runCalendarWorkspaceStateTests()`:

```swift
let start = Date(timeIntervalSince1970: 1_750_000_000)
let event = CalendarEventSnapshot(id: "meeting", calendarID: "work", calendarTitle: "Work",
    title: "Planning across cities", startDate: start, endDate: start.addingTimeInterval(3600),
    isAllDay: false, attendeeNames: [], availability: .busy, participationStatus: .accepted)
CalendarWorkspaceEventActivation.select(event, referenceMoment: reference)
workspaceExpect(presentation.destination == .calendar, "timed selection stays in workspace")
workspaceExpect(reference.timeState.referenceDate == start, "rail receives event instant")
let zones = (0..<8).map { ZoneInfo(label: "City \($0)", timeZoneId: "America/New_York") }
let cards = zones.map { CalendarRailCardPresentation(zone: $0, date: reference.timeState.referenceDate) }
workspaceExpect(cards.count == 8 && cards.allSatisfy { !$0.time.isEmpty }, "every active city is represented")
workspaceExpect([ZoneInfo]().map { CalendarRailCardPresentation(zone: $0, date: start) }.isEmpty,
                "no saved cities produces an empty list rather than a dummy city")
let allDay = CalendarEventSnapshot(id: "holiday", calendarID: "work", calendarTitle: "Work",
    title: "Holiday", startDate: start.addingTimeInterval(86400), endDate: start.addingTimeInterval(172800),
    isAllDay: true, attendeeNames: [], availability: .free, participationStatus: .accepted)
CalendarWorkspaceEventActivation.select(allDay, referenceMoment: reference)
workspaceExpect(reference.timeState.referenceDate == start, "all-day activation cannot change rail instant")
reference.goLive()
workspaceExpect(presentation.destination == .calendar && reference.selectedEvent == nil,
                "Now clears context without exiting workspace")
```

Replace the old test that manually called `returnToTimeZoner()` after selection and claimed selection returns. Keep separate explicit-return coverage. Update the icon tuple expectations in `CalendarRangeTests` to the exact metadata in Step 3. Run `cd app && swift run TimeZonerTests`; expect undefined rail/activation types and the old icon metadata mismatch.

- [ ] **Step 2: Implement rail values and event activation**

Append to `CalendarWorkspaceState.swift`:

```swift
public struct CalendarRailCardPresentation: Equatable, Sendable {
    public let title: String
    public let time: String
    public let date: String
    public let offset: String
    public var accessibilityLabel: String { "\(title), \(time), \(date), \(offset)" }
    public init(zone: ZoneInfo, date: Date) {
        title = zone.label
        time = TimeFormatter.formatTime(date, in: zone.timeZone)
        self.date = TimeFormatter.formatDate(date, in: zone.timeZone)
        offset = TimeFormatter.gmtOffset(for: zone.timeZone, at: date)
    }
}

public enum CalendarWorkspaceEventActivation {
    public static func select(_ event: CalendarEventSnapshot, referenceMoment: ReferenceMomentController) {
        referenceMoment.selectEvent(event, sourceZone: .current)
    }
}
```

In `CalendarModeView.selectTimedEvent`, use only `CalendarWorkspaceEventActivation.select(event, referenceMoment: referenceMoment)`. Delete the return callback from the initializer and stored properties. All-day details continue through the existing `showEventDetails` path.

- [ ] **Step 3: Change both expand-control identities**

Replace `CalendarNavigationIconControl` in `CalendarRange.swift` with:

```swift
public enum CalendarNavigationIconControl: Equatable, Sendable {
    case expandCalendar, expandTimeZoner
    public var systemImageName: String { "arrow.up.left.and.arrow.down.right" }
    public var accessibilityLabel: String {
        self == .expandCalendar ? "Expand calendar" : "Expand TimeZoner"
    }
    public var helpText: String { accessibilityLabel }
    public var accessibilityHint: String {
        self == .expandCalendar
            ? "Shows the calendar with your time zones beside it."
            : "Restores the full TimeZoner view and compact agenda."
    }
}
```

Use `CalendarToolbarIcon` for Agenda's expand action, replacing `.openWeek` with `.expandCalendar`. Keep the action closure itself named `onOpenWeek` for now to avoid an unrelated API rename. Remove the calendar view's back control entirely. Update both existing tuple tests to the new case names and strings; do not merely delete accessibility expectations.

- [ ] **Step 4: Implement the read-only compact rail**

Create `TimeZonerRailView.swift` with explicit public initializer and the following body/helpers:

```swift
import SwiftUI

public struct TimeZonerRailView: View {
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let onExpand: () -> Void
    public init(zones: [ZoneInfo], referenceMoment: ReferenceMomentController,
                presentation: CalendarPresentationState, onExpand: @escaping () -> Void) {
        self.zones = zones; self.referenceMoment = referenceMoment
        self.presentation = presentation; self.onExpand = onExpand
    }

    public var body: some View {
        CalendarPanelChrome(isHugging: presentation.mainPanelHugsMenuBar,
                            isFocused: presentation.focusedPanel == .timezoner) {
            HStack(spacing: 8) {
                Button("Now") { referenceMoment.goLive() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(width: 54, height: 40)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
                    .foregroundStyle(referenceMoment.timeState.isLive ? Theme.textTertiary : Theme.accent)
                Spacer(minLength: 0)
                CalendarToolbarIcon(systemName: CalendarNavigationIconControl.expandTimeZoner.systemImageName,
                    label: CalendarNavigationIconControl.expandTimeZoner.accessibilityLabel,
                    hint: CalendarNavigationIconControl.expandTimeZoner.accessibilityHint, action: onExpand)
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                context.frame(height: 44, alignment: .topLeading)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 10) {
                        if zones.isEmpty {
                            Text("No saved cities\nExpand TimeZoner to add a city.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(zones) { zone in
                            card(CalendarRailCardPresentation(zone: zone, date: referenceMoment.timeState.referenceDate))
                        }
                    }
                }
            }
        }
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(referenceMoment.selectedEvent?.title ?? "Current time")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(contextTime)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(referenceMoment.selectedEvent?.title ?? "Current time"), \(contextTime)")
        .help(referenceMoment.selectedEvent?.title ?? "Current time")
    }

    private var contextTime: String {
        let date = referenceMoment.timeState.referenceDate
        return "\(TimeFormatter.formatDate(date, in: .current)) · \(TimeFormatter.formatTime(date, in: .current)) \(TimeZone.current.abbreviation(for: date) ?? TimeZone.current.identifier)"
    }

    private func card(_ value: CalendarRailCardPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(value.title).font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value.offset).font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(value.time).font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(value.date).font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.accessibilityLabel)
    }
}
```

The context slot's `.lineLimit(2)` plus metadata must fit 44 points at the specified fonts; verify long titles natively. Add `@AccessibilityFocusState private var contextFocused: Bool` to the rail, `.accessibilityFocused($contextFocused)` to `context`, and this modifier to the rail root:

```swift
.onReceive(NotificationCenter.default.publisher(for: .focusSelectedEventContext)) { _ in
    guard presentation.destination == .calendar, referenceMoment.selectedEvent != nil else { return }
    DispatchQueue.main.async { contextFocused = true }
}
```

Focus context only when that notification arrives, not on every event selection.

- [ ] **Step 5: Build the single-row calendar toolbar with compact fallback**

Create `CalendarWorkspaceToolbar.swift`:

```swift
import SwiftUI

public struct CalendarWorkspaceToolbar: View {
    public let calendarStore: CalendarStore
    public let presentation: CalendarPresentationState
    public let settingsButton: CalendarSettingsButton<SettingsPopover>
    public init(calendarStore: CalendarStore, presentation: CalendarPresentationState,
                settingsButton: CalendarSettingsButton<SettingsPopover>) {
        self.calendarStore = calendarStore; self.presentation = presentation
        self.settingsButton = settingsButton
    }
    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width + 2 * CalendarPanelMetrics.horizontalInset
                < CalendarPanelMetrics.compactToolbarThreshold
            HStack(spacing: compact ? 4 : 8) {
                if compact {
                    Picker("Calendar range", selection: selection) {
                        rangeOptions
                    }
                    .pickerStyle(.menu)
                    .frame(width: 76)
                } else {
                    Picker("Calendar range", selection: selection) {
                        rangeOptions
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 184)
                }
                CalendarToolbarIcon(systemName: "chevron.left", label: "Previous \(rangeName)",
                    hint: "Moves to the previous calendar range.") { move(.previous) }
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(minWidth: compact ? 45 : 66)
                    .accessibilityLabel(title)
                CalendarToolbarIcon(systemName: "chevron.right", label: "Next \(rangeName)",
                    hint: "Moves to the next calendar range.") { move(.next) }
                Button("Today") {
                    presentation.goToday(now: calendarStore.currentDate, calendar: calendarStore.localCalendar)
                    refresh()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 36, minHeight: 28)
                .accessibilityLabel("Jump to today")
                Spacer(minLength: 0)
                settingsButton
            }
            .controlSize(.small)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .frame(height: CalendarPanelMetrics.navHeight)
        }
        .frame(height: CalendarPanelMetrics.navHeight)
    }
    private var selection: Binding<CalendarRangeSelection> {
        Binding(get: { presentation.range }, set: { presentation.setRange($0); refresh() })
    }
    private var rangeOptions: some View {
        Group {
            Text("Today").tag(CalendarRangeSelection.today).accessibilityLabel("Day view")
            Text("3 Day").tag(CalendarRangeSelection.threeDays).accessibilityLabel("Three day view")
            Text("Week").tag(CalendarRangeSelection.week).accessibilityLabel("Week view")
        }
    }
    private var rangeName: String {
        switch presentation.range { case .today: "day"; case .threeDays: "three days"; case .week: "week" }
    }
    private var title: String {
        CalendarRangeHeaderPresentation.title(for: presentation.range,
            interval: presentation.activeInterval(calendar: calendarStore.localCalendar),
            currentDate: calendarStore.currentDate, calendar: calendarStore.localCalendar)
    }
    private func move(_ direction: CalendarRangeNavigationDirection) {
        presentation.move(direction, calendar: calendarStore.localCalendar)
        refresh()
    }
    private func refresh() {
        guard calendarStore.authorizationStatus == .fullAccess else { return }
        calendarStore.refreshPresentationInterval()
    }
}
```

Use a 28-point range selector height where the native picker supports it; retain the 40-point parent slot. At 360 calendar points the compact controls fit in the 320-point inset width. Replace `Text(title)` with `Text(compact ? compactTitle : title)` while retaining `.accessibilityLabel(title)`. Define:

```swift
private var compactTitle: String {
    guard presentation.range != .week else { return title }
    let formatter = DateFormatter()
    formatter.locale = calendarStore.localCalendar.locale ?? .current
    formatter.timeZone = calendarStore.localCalendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: presentation.activeInterval(calendar: calendarStore.localCalendar).start)
}
```

- [ ] **Step 6: Adopt the chrome without adding a second inner shell**

Move the existing normal HStack into `ContentView.normalHeader`; move its cards/context/map into `normalBody`. Replace its outer stacks/background/clip with:

```swift
private var normalContent: some View {
    CalendarPanelChrome(isHugging: presentation.mainPanelHugsMenuBar,
                        isFocused: presentation.focusedPanel == .timezoner) {
        normalHeader
    } content: {
        normalBody
    }
}
```

Keep `normalBody`'s existing context, ZoneCardRow, and map logic and its 14-point content spacing. Remove their old outer `.padding(.horizontal, 20)`, top/bottom padding, `.frame(width: idealWidth)`, and `.fixedSize` so the native window owns its frame. Replace `idealWidth`'s calculation with `CalendarPanelMetrics.normalWidth(cityCount: zoneStore.zones.count)`. Give the normal ChatField a flexible width; give Now exactly 54 × 40; use `CalendarToolbarIcon` for calendar and the shared settings button for settings. Remove the duplicate inline access card below normal content because Agenda already owns recovery.

Change `ContentView.body`'s destination branch to:

```swift
if presentation.destination == .calendar {
    TimeZonerRailView(zones: zoneStore.zones, referenceMoment: referenceMoment,
                     presentation: presentation, onExpand: returnFromCalendarMode)
} else {
    normalContent
}
```

Agenda uses the same chrome, with its existing header and scrollable content. Remove its own DragHandle, outer paddings, background/clip, and fixed 220-point root width; the panel/popover provides width. Header HStack uses `.center`, its title block retains 14/11-point text, and its expand uses the shared 28-point target.

CalendarModeView uses the same chrome, `presentation.agendaPanelHugsMenuBar`, focused identity `.calendar`, and `CalendarWorkspaceToolbar`. Place the existing date-range string plus the local timezone abbreviation in an 11-point subtitle above its grid within the content slot. Remove its old two-row header and redundant outer shell.

- [ ] **Step 7: Keep narrow-grid layers together**

At the CalendarModeView grid call site, wrap the entire `CalendarTimeGrid` (not individual strips) in one horizontal scroll view, with a minimum grid width of 700 for Week, 420 for 3 Day, and 0 for Today. Add these exact computed values:

```swift
private var minimumGridWidth: CGFloat {
    switch presentation.range { case .today: 0; case .threeDays: 420; case .week: 700 }
}
```

Use a `GeometryReader` in the content grid slot:

```swift
GeometryReader { proxy in
    ScrollView(.horizontal) {
        calendarGrid.frame(width: max(proxy.size.width, minimumGridWidth), height: proxy.size.height)
    }
}
```

Extract the existing `CalendarTimeGrid(...)` call, with all of its current event/popover callbacks intact, into `private var calendarGrid: some View`. Its existing vertical scroller remains internal. Its header/all-day/timed layers continue consuming the same `CalendarGridHorizontalLayout`. Do not add independent horizontal scroll containers or return to separate layer width calculations.

- [ ] **Step 8: Compose the agenda/full-calendar root and cancellable input focus**

Create the root:

```swift
import SwiftUI

public struct CalendarPanelRootView: View {
    public let presentation: CalendarPresentationState
    public let agenda: AgendaView
    public let calendar: CalendarModeView
    public init(presentation: CalendarPresentationState, agenda: AgendaView, calendar: CalendarModeView) {
        self.presentation = presentation; self.agenda = agenda; self.calendar = calendar
    }
    public var body: some View {
        Group {
            if presentation.destination == .calendar { calendar }
            else { agenda }
        }
    }
}
```

In `AppDelegate.createPanel`, use this root for `agendaPanel`'s hosting view and keep the normal fallback popover rooted at `makeAgendaView`. Build `CalendarModeView` using the same stores and a `CalendarSettingsButton(owner: .calendar, ...)` that wraps the existing `SettingsPopover(...)` initialization. The main settings instance uses `.timezoner`. Until Task 5 adds the centralized native action, `onActivate` sets `presentation.isSettingsPresented.toggle()` and updates popover protection exactly as the existing main settings action did.

Guard ContentView's hidden `⌘N` action with `destination == .timezoner`. Replace ChatField's uncancellable `.onAppear` delayed focus with a cancellable task:

```swift
.task {
    do { try await Task.sleep(for: .milliseconds(300)) }
    catch { return }
    guard !Task.isCancelled else { return }
    isFocused = true
}
```

The coordinator will request focus after a completed normal restoration. Do not call `NSApp.activate` from this task, as a stale field must not foreground the app. In Task 5 move both layout transitions entirely into the coordinator; this task may build while retaining the old native switching behavior temporarily.

- [ ] **Step 9: Run tests/build and commit the view composition**

Run `cd app && swift run TimeZonerTests` and `./scripts/build.sh`. Expected: tests pass and both target roots compile. Search `rg -n 'onReturnToTimeZoner|backToTimeZoner|openWeek' app/Sources app/Tests`; expected no obsolete return/icon symbols (the intentional `onOpenWeek` action spelling is case-distinct and may remain).

```bash
git add app/Sources/Models/CalendarWorkspaceState.swift app/Sources/Models/CalendarRange.swift app/Sources/Views/TimeZonerRailView.swift app/Sources/Views/CalendarWorkspaceToolbar.swift app/Sources/Views/CalendarPanelRootView.swift app/Sources/Views/ContentView.swift app/Sources/Views/AgendaView.swift app/Sources/Views/CalendarModeView.swift app/Sources/Views/CalendarTimeGrid.swift app/Sources/Views/ChatField.swift app/Sources/App/TimeZonerApp.swift app/Tests/CalendarWorkspaceStateTests.swift app/Tests/CalendarRangeTests.swift app/Tests/CalendarPresentationStateTests.swift
git commit -m "feat: compose calendar workspace and compact city rail"
```

### Task 5: Persistent panel ownership, focus, and restoration

**Files:**
- Modify: `app/Sources/Models/CalendarPresentationState.swift` (pair controller and panel protocol)
- Modify: `app/Sources/App/CalendarPanelCoordinator.swift`, `app/Sources/App/FloatingPanel.swift`, `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Sources/Views/ContentView.swift`, `app/Sources/Views/CalendarPanelRootView.swift`, `app/Sources/Views/TimeZonerRailView.swift`
- Modify: `app/Tests/CalendarPanelCoordinatorTests.swift`, `app/Tests/PendingCalendarCommandTests.swift`, `app/Tests/TimeZonerDeepLinkTests.swift`

**Interfaces:**
- Adds to `CalendarPanelPairController`: `workspaceFrames: CalendarWorkspaceFrames?` (read-only outside), `beginWorkspace(_:applyFrames:focusCalendar:)`, `endWorkspace(_:showAgenda:)`, `focusTimeZoner()`, `setTransitionInProgress(_:)`.
- Adds to `CalendarPanelControlling` and proxy: `focusTimeZoner()`, `toggleSettings()`, `restoreTimeZonerImmediately()`.
- Changes coordinator initializer to also consume `cityCount: () -> Int`, `prepareCalendar: () -> Void`, and `refreshCalendar: () -> Void`.
- Coordinator owns one `savedNormalLayout: CalendarNormalLayoutSnapshot?`; presentation owns destination, not geometry.
- FloatingPanel adds `persistsNormalPosition: Bool` and `floatingPanelDidBecomeKey(_:)` delegate callback.

- [ ] **Step 1: Write paired-window lifecycle tests using the existing fakes**

Inside `runCalendarPanelCoordinatorTests()`, append:

```swift
do {
    let scheduler = CalendarPanelDeferredSchedulerFake()
    let mainFrame = CGRect(x: 300, y: 100, width: 400, height: 500)
    let main = CalendarPanelSurfaceFake(frame: mainFrame)
    let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
    let popover = CalendarPanelPopoverFake()
    let pair = CalendarPanelPairController(main: main, agenda: agenda, agendaPopover: popover,
        visibleFrame: { visible }, scheduleDeferredDismissal: scheduler.schedule)
    pair.show(showAgenda: true)
    let frames = CalendarWorkspaceLayout.calculate(main: main.frame, agenda: agenda.frame,
        placement: .right, visibleFrame: visible)
    pair.beginWorkspace(frames, applyFrames: true, focusCalendar: true)
    expectCalendarPanel(main.isVisible && agenda.isVisible && !popover.isPresented,
                        "workspace has two real windows")
    expectCalendarPanel(main.frame == frames.main && agenda.frame == frames.calendar,
                        "workspace uses the pair frame solution")
    pair.syncAgendaVisibility(showAgenda: false)
    expectCalendarPanel(agenda.isVisible, "normal agenda preference cannot hide workspace calendar")
    main.isKey = false; agenda.isKey = true
    pair.panelDidResignKey(); scheduler.runAll()
    expectCalendarPanel(main.isVisible && agenda.isVisible, "calendar key focus retains both windows")
    pair.setOwnedPopoverPresented(true)
    agenda.isKey = false
    pair.panelDidResignKey(); scheduler.runAll()
    expectCalendarPanel(main.isVisible && agenda.isVisible, "calendar settings retains both windows")
    let restoration = CalendarWorkspaceRestoration(main: mainFrame,
        agenda: AgendaPlacementResult(location: .right,
            frame: CGRect(x: 710, y: 20, width: 220, height: 580)))
    pair.endWorkspace(restoration, showAgenda: false)
    expectCalendarPanel(main.frame == mainFrame && !agenda.isVisible,
                        "return honors a changed normal agenda preference")
    expectCalendarPanel(pair.workspaceFrames == nil, "normal attachment resumes after return")
}
```

Run `cd app && swift run TimeZonerTests`; expect missing new pair methods.

- [ ] **Step 2: Teach the pair controller its workspace mode**

Add these stored members and methods to `CalendarPanelPairController`:

```swift
public private(set) var workspaceFrames: CalendarWorkspaceFrames?
private var transitionInProgress = false

public func setTransitionInProgress(_ value: Bool) { transitionInProgress = value }

public func beginWorkspace(_ frames: CalendarWorkspaceFrames, applyFrames: Bool = true,
                           focusCalendar: Bool = true) {
    workspaceFrames = frames
    placement = .right
    agendaPopover.dismiss()
    if applyFrames {
        main.setFrame(frames.main)
        agenda.setFrame(frames.calendar)
    }
    main.show()
    agenda.show()
    if focusCalendar { agenda.focus() }
}

public func endWorkspace(_ restored: CalendarWorkspaceRestoration, showAgenda: Bool) {
    workspaceFrames = nil
    main.setFrame(restored.main)
    agenda.setFrame(restored.agenda.frame ?? CGRect(
        x: restored.main.maxX + 10, y: restored.main.maxY - 580, width: 220, height: 580))
    placement = restored.agenda.location
    if !showAgenda {
        agendaPopover.dismiss(); agenda.hide()
    } else if placement == .popover {
        agenda.hide(); agendaPopover.show()
    } else {
        agendaPopover.dismiss(); agenda.show()
    }
    main.focus()
}

public func focusTimeZoner() {
    guard main.isVisible else { return }
    main.focus()
}
```

At the top of `syncAgendaVisibility`, before its normal placement calculation:

```swift
guard !transitionInProgress else { return }
if workspaceFrames != nil {
    agendaPopover.dismiss()
    if main.isVisible { agenda.show() } else { agenda.hide() }
    return
}
```

In `show(showAgenda:)`, use `workspaceFrames == nil ? main.focus() : agenda.focus()` after syncing. In `resizeMain`, return immediately when `workspaceFrames != nil` or `transitionInProgress`; retain normal center-x but replace center-y anchoring with `y: oldFrame.maxY - size.height` so city changes do not move the nav top. In the deferred resignation closure, include `!transitionInProgress` in the existing visibility/focus guards. Add the three protocol methods listed in Interfaces and forwarding methods on `CalendarPanelControllerProxy`.

- [ ] **Step 3: Move mode switching entirely into the native coordinator**

Replace the coordinator's two saved-frame properties with:

```swift
private var savedNormalLayout: CalendarNormalLayoutSnapshot?
private let cityCount: () -> Int
private let prepareCalendar: () -> Void
private let refreshCalendar: () -> Void
```

Accept/store the closures in its initializer. Use `screenIdentifier(for: mainPanel.screen)?.stringValue` when creating the value snapshot. Replace the entry/return methods with this immediate, testable routing first:

```swift
func enterCalendarMode() {
    guard savedNormalLayout == nil else { return }
    savedNormalLayout = CalendarNormalLayoutSnapshot(main: mainPanel.frame,
        agenda: agendaPanel.isVisible ? agendaPanel.frame : nil, placement: pair.placement,
        screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
        visibleFrame: visibleFrame(), cityCount: cityCount())
    closeOwnedPopovers()
    mainPanel.persistsNormalPosition = false
    let frames = CalendarWorkspaceLayout.calculate(main: mainPanel.frame,
        agenda: agendaPanel.isVisible ? agendaPanel.frame : nil, placement: pair.placement,
        visibleFrame: visibleFrame())
    prepareCalendar()
    updateAttachment { pair.beginWorkspace(frames) }
    refreshCalendar()
}

func returnToTimeZoner() { restoreTimeZonerImmediately() }

func restoreTimeZonerImmediately() {
    guard let snapshot = savedNormalLayout else { return }
    closeOwnedPopovers()
    let restored = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: visibleFrame(),
        screenID: screenIdentifier(for: mainPanel.screen)?.stringValue, cityCount: cityCount())
    presentation.returnToTimeZoner()
    updateAttachment { pair.endWorkspace(restored, showAgenda: presentation.showAgendaWing) }
    savedNormalLayout = nil
    mainPanel.persistsNormalPosition = true
    refreshCalendar()
    NotificationCenter.default.post(name: .focusChatField, object: nil)
}

private func closeOwnedPopovers() {
    presentation.isSettingsPresented = false
    presentation.eventDetailPopoverTarget = nil
    pair.setOwnedPopoverPresented(false)
}

func focusTimeZoner() { pair.focusTimeZoner() }

func toggleSettings() {
    let opening = !presentation.isSettingsPresented
    if opening {
        switch CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) {
        case .timezoner: mainPanel.makeKey()
        case .calendar: agendaPanel.makeKey()
        }
    }
    presentation.isSettingsPresented = opening
    pair.setOwnedPopoverPresented(presentation.hasOwnedPopover)
}
```

`show()` and `syncAgendaVisibility()` must pass `CalendarWorkspacePolicy.calendarVisible(destination:showAgenda:)` rather than the old `.timezoner && showAgendaWing` predicate. Do not let normal placement move the calendar while `workspaceFrames` exists. In ContentView's initial `.onAppear`, before consuming a pending deep link, size normal content once:

```swift
if presentation.destination == .timezoner {
    panelController?.resizeMain(to: CGSize(width: idealWidth, height: CalendarPanelMetrics.preferredHeight))
}
```

In `ContentView.returnFromCalendarMode`, call only `panelController?.returnToTimeZoner()`. The external deep-link restoration callback uses `panelController?.restoreTimeZonerImmediately()` and refreshes the presentation interval after restoration. Preserve the existing deep-link router's restore-before-apply contract. These changes remove double destination/frame changes from the SwiftUI action.

- [ ] **Step 4: Wire actual shared objects and settings commands**

At coordinator construction in AppDelegate, supply:

```swift
cityCount: { [zoneStore] in zoneStore.zones.count },
prepareCalendar: { [weak self] in
    guard let self else { return }
    self.presentation.enterCalendar(now: self.calendarStore.currentDate,
                                    calendar: self.calendarStore.localCalendar)
},
refreshCalendar: { [weak self] in
    guard let self, self.calendarStore.authorizationStatus == .fullAccess else { return }
    self.calendarStore.refreshPresentationInterval()
}
```

`openCalendarMode(panelProxy:)` now calls only `panelProxy.enterCalendarMode()`. Remove its full-access guard, direct `presentation.enterCalendar`, and direct refresh: recovery is allowed in the expanded calendar, and the injected refresh closure remains permission-safe.

Route both settings icons and both key-window `⌘,` actions through `panelProxy.toggleSettings()` / `panelController?.toggleSettings()`. Add `onToggleSettings: () -> Void` and `onFocusCalendar: () -> Void` to `CalendarPanelRootView`'s public initializer and stored properties, then attach:

```swift
.background {
    Button("") { onToggleSettings() }.keyboardShortcut(",", modifiers: .command).hidden()
}
.background {
    Button("") { onFocusCalendar() }.keyboardShortcut("a", modifiers: [.command, .shift]).hidden()
}
```

Pass `panelProxy.toggleSettings` and `{ panelProxy.focusAgenda() }` when constructing the calendar root. ContentView's `focusAgendaFromKeyboard` uses `CalendarWorkspacePolicy.calendarVisible` instead of requiring `.timezoner`. Do not register a second global Carbon hotkey.

- [ ] **Step 5: Track focus without persisting temporary rail positions**

Add `floatingPanelDidBecomeKey(_ panel: FloatingPanel)` to `FloatingPanelInteractionDelegate`. In FloatingPanel:

```swift
var persistsNormalPosition = true

override func becomeKey() {
    super.becomeKey()
    interactionDelegate?.floatingPanelDidBecomeKey(self)
}
```

Change the save condition in `windowDidMove` to `if role == .main && persistsNormalPosition { savePosition() }`. The coordinator keeps this false throughout the workspace, including user pair-drags, and restores it only after normal restoration is fully applied. No migration to the existing `panelPosition` key is needed.

In the coordinator's delegate extension:

```swift
func floatingPanelDidBecomeKey(_ panel: FloatingPanel) {
    presentation.focusedPanel = panel === mainPanel ? .timezoner : .calendar
}
```

Keep the existing deferred resign-key handling. Clear `focusedPanel` when the pair actually hides. Closing settings/details before a transition may schedule a deferred check; `setTransitionInProgress(true)` must already be active when Task 6 adds asynchronous motion.

- [ ] **Step 6: Observe both panels and translate the workspace as one pair**

Replace `observeMainPanel` with `observePanels`: register move/resize/screen notifications for both existing windows, still observing application deactivation once. Native notification objects identify the moved panel. Add this method and route each frame notification through it:

```swift
private func panelFrameChanged(_ panel: FloatingPanel, screenChanged: Bool) {
    guard !isUpdatingAttachment else { return }
    guard let frames = pair.workspaceFrames else {
        if panel === mainPanel { syncAgendaVisibility() }
        return
    }
    let oldFrame = panel === mainPanel ? frames.main : frames.calendar
    let screen = panel.screen?.visibleFrame ?? visibleFrame()
    let adjusted: CalendarWorkspaceFrames
    if screenChanged {
        adjusted = CalendarWorkspaceLayout.calculate(main: mainPanel.frame,
            agenda: agendaPanel.frame, placement: .right, visibleFrame: screen)
    } else {
        adjusted = CalendarWorkspaceLayout.translated(frames,
            by: CGSize(width: panel.frame.minX - oldFrame.minX,
                       height: panel.frame.minY - oldFrame.minY), visibleFrame: screen)
    }
    updateAttachment { pair.beginWorkspace(adjusted, focusCalendar: false) }
}
```

During Task 6, add a transition guard here and settle on a screen-change notification. Also observe `NSApplication.didChangeScreenParametersNotification`: recalculate using a connected screen when the stored display disappears, even if no move was emitted. Keep `savedNormalLayout` untouched while moving the workspace. Use the layout suite's translation/removed-screen tests as the algorithm evidence; native dual-screen movement is a manual gate.

- [ ] **Step 7: Keep notification activation in the current workspace**

Replace AppDelegate's `restoreTimeZonerSurfaceForNotification` callback with a preparation callback that does not change destination. In Task 6 it will settle a running transition before presentation. In `focusSelectedEventContext`, call `panelCoordinator?.focusTimeZoner()` before posting `.focusSelectedEventContext`, so selection focuses the rail after the existing notification router has shown the pair.

Update the existing two routing-accessibility blocks in `PendingCalendarCommandTests`: use a preparation callback that only appends `"prepare"`; expect `.calendar` afterward, and assert `["prepare", "show", "fresh", "focus"]` / `["prepare", "show", "fallback", "focus"]`. Retain fresh/fallback event date/source assertions. The core notification scheduling behavior is untouched.

Keep the existing deep-link tests asserting normal restoration. Add this case inside the existing deep-link test suite using its assertion helper or `workspaceExpect`:

```swift
let suite = "WorkspaceDeepLink.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let presentation = CalendarPresentationState(defaults: defaults)
presentation.enterCalendar(now: Date(timeIntervalSince1970: 1_750_000_000), calendar: .current)
var order: [String] = []
TimeZonerDeepLinkPresentationRouter.route(
    .setTime(hour: 15, minute: 30, zoneID: "Asia/Tokyo", label: "Tokyo"),
    presentation: presentation, restoreTimeZonerPanel: { order.append("restore") },
    apply: { _ in order.append("apply") })
workspaceExpect(presentation.destination == .timezoner && order == ["restore", "apply"],
                "explicit timezone command restores normal editing before adding a city")
```

- [ ] **Step 8: Test/build the static end states before adding animation**

Run `cd app && swift run TimeZonerTests`, then `./scripts/build.sh`. Expected: all tests pass; native app compiles. Task 6 adds the explicit transition-from-popover lifecycle test before introducing asynchronous switching.

Commit:

```bash
git add app/Sources/Models/CalendarPresentationState.swift app/Sources/App/CalendarPanelCoordinator.swift app/Sources/App/FloatingPanel.swift app/Sources/App/TimeZonerApp.swift app/Sources/Views/ContentView.swift app/Sources/Views/CalendarPanelRootView.swift app/Sources/Views/TimeZonerRailView.swift app/Tests/CalendarPanelCoordinatorTests.swift app/Tests/PendingCalendarCommandTests.swift app/Tests/TimeZonerDeepLinkTests.swift
git commit -m "feat: coordinate persistent calendar workspace panels"
```

### Task 6: One interruptible transition timeline and Reduce Motion

**Files:**
- Modify: `app/Sources/Models/CalendarWorkspaceState.swift`, `app/Sources/Models/CalendarPresentationState.swift`
- Create: `app/Tests/CalendarWorkspaceTransitionTests.swift`
- Modify: `app/Sources/App/CalendarPanelCoordinator.swift`, `app/Sources/App/TimeZonerApp.swift`
- Modify: `app/Sources/Views/ContentView.swift`, `app/Sources/Views/AgendaView.swift`, `app/Sources/Views/CalendarModeView.swift`, `app/Sources/Views/TimeZonerRailView.swift`
- Modify: `app/Tests/CalendarPanelCoordinatorTests.swift`, `app/Tests/TimeZonerTests.swift`

**Interfaces:**
- Produces `CalendarWorkspaceMotion(reduceMotion:)` with `fadeOut`, `move`, `fadeIn`, and `travel`.
- Produces `CalendarWorkspaceTransitionGate.begin(to:) -> Request?`, `isCurrent(_:) -> Bool`, `finish(_:) -> CalendarDestination?`, `cancel() -> CalendarDestination?`, and `active: Request?`.
- Adds presentation values `workspaceContentOpacity: Double = 1`, `workspaceContentOffset: CGFloat = 0`, `isWorkspaceTransitioning = false`.
- Native coordinator exposes `settleWorkspaceTransition()` internally for hide, display changes, accessibility changes, and notification preparation. The panel protocol exposes that same method for the proxy if a caller needs it.

- [ ] **Step 1: Write coalescing, interruption, and reduced-motion tests**

Create and register `runCalendarWorkspaceTransitionTests()`:

```swift
import Foundation
import TimeZonerLib

func runCalendarWorkspaceTransitionTests() {
    var gate = CalendarWorkspaceTransitionGate()
    let opening = gate.begin(to: .calendar)!
    workspaceExpect(gate.begin(to: .timezoner) == nil, "second request queues instead of racing")
    workspaceExpect(gate.begin(to: .calendar) == nil, "latest request replaces earlier queued target")
    workspaceExpect(gate.finish(opening.id) == nil, "same final target requires no extra transition")
    workspaceExpect(gate.active == nil, "completed timeline clears active token")

    let next = gate.begin(to: .calendar)!
    _ = gate.begin(to: .timezoner)
    workspaceExpect(gate.finish(next.id) == .timezoner, "reverse request survives current completion")
    let reverse = gate.begin(to: .timezoner)!
    workspaceExpect(!gate.isCurrent(opening.id), "old completion cannot operate on new transition")
    workspaceExpect(gate.cancel() == .timezoner, "hide settles the latest requested destination")
    workspaceExpect(!gate.isCurrent(reverse.id) && gate.finish(reverse.id) == nil,
                    "completion after hide cannot resurrect a panel")

    let normal = CalendarWorkspaceMotion(reduceMotion: false)
    let reduced = CalendarWorkspaceMotion(reduceMotion: true)
    workspaceExpect(abs(normal.fadeOut + normal.move + normal.fadeIn - 0.34) < 0.000001,
                    "normal transition has one 340ms timeline")
    workspaceExpect(reduced.move == 0 && reduced.travel == 0,
                    "Reduce Motion has no frame animation or content travel")
    workspaceExpect(abs(reduced.fadeOut + reduced.fadeIn - 0.1) < 0.000001,
                    "Reduce Motion keeps a short opacity transition")
}
```

Run `cd app && swift run TimeZonerTests`; expected: missing gate/motion types.

- [ ] **Step 2: Implement the pure gate and timing**

Append to `CalendarWorkspaceState.swift`:

```swift
public struct CalendarWorkspaceMotion: Equatable, Sendable {
    public let fadeOut: TimeInterval
    public let move: TimeInterval
    public let fadeIn: TimeInterval
    public let travel: CGFloat
    public init(reduceMotion: Bool) {
        fadeOut = reduceMotion ? 0.05 : 0.06
        move = reduceMotion ? 0 : 0.22
        fadeIn = reduceMotion ? 0.05 : 0.06
        travel = reduceMotion ? 0 : 4
    }
}

public struct CalendarWorkspaceTransitionGate {
    public struct Request: Equatable, Sendable {
        public let id: UInt64
        public let destination: CalendarDestination
    }
    public private(set) var active: Request?
    private var queued: CalendarDestination?
    private var serial: UInt64 = 0
    public init() {}

    public mutating func begin(to destination: CalendarDestination) -> Request? {
        guard active == nil else { queued = destination; return nil }
        serial &+= 1
        let request = Request(id: serial, destination: destination)
        active = request
        return request
    }
    public func isCurrent(_ id: UInt64) -> Bool { active?.id == id }
    public mutating func finish(_ id: UInt64) -> CalendarDestination? {
        guard let completed = active, completed.id == id else { return nil }
        let next = queued
        active = nil; queued = nil
        return next == completed.destination ? nil : next
    }
    public mutating func cancel() -> CalendarDestination? {
        let destination = queued ?? active?.destination
        serial &+= 1
        active = nil; queued = nil
        return destination
    }
}
```

Add the three presentation values listed in Interfaces. At every `CalendarPanelChrome` call site, pass:

```swift
contentOpacity: presentation.workspaceContentOpacity,
contentOffset: presentation.workspaceContentOffset,
interactionEnabled: !presentation.isWorkspaceTransitioning
```

Do not attach an implicit destination animation to either root; the coordinator supplies the animation transaction. Disable ContentView's existing city-count/time-adjustment implicit animations while `isWorkspaceTransitioning` is true by choosing `nil` instead of the existing `.easeInOut(...)` in those two modifiers.

- [ ] **Step 3: Define native transition targets independently of visible content**

Add `import QuartzCore` to the coordinator and these members/helpers. Keep the saved snapshot for the entire calendar session; only completion of a normal return clears it.

```swift
private struct NativeWorkspaceTarget {
    let destination: CalendarDestination
    let main: CGRect
    let calendar: CGRect
    let workspace: CalendarWorkspaceFrames?
    let restoration: CalendarWorkspaceRestoration?
}

private var transitionGate = CalendarWorkspaceTransitionGate()
private var activeNativeTarget: NativeWorkspaceTarget?

private func target(for destination: CalendarDestination) -> NativeWorkspaceTarget? {
    if destination == .calendar {
        if savedNormalLayout == nil {
            savedNormalLayout = CalendarNormalLayoutSnapshot(main: mainPanel.frame,
                agenda: agendaPanel.isVisible ? agendaPanel.frame : nil, placement: pair.placement,
                screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
                visibleFrame: visibleFrame(), cityCount: cityCount())
        }
        guard let saved = savedNormalLayout else { return nil }
        let frames = CalendarWorkspaceLayout.calculate(main: saved.main, agenda: saved.agenda,
            placement: saved.placement, visibleFrame: visibleFrame())
        return NativeWorkspaceTarget(destination: .calendar, main: frames.main,
            calendar: frames.calendar, workspace: frames, restoration: nil)
    }
    guard let saved = savedNormalLayout else { return nil }
    let restored = CalendarWorkspaceLayout.restore(saved, visibleFrame: visibleFrame(),
        screenID: screenIdentifier(for: mainPanel.screen)?.stringValue, cityCount: cityCount())
    let visible = visibleFrame()
    let width = min(CGFloat(220), visible.width)
    let height = min(CGFloat(580), visible.height)
    let temporaryAgenda = CGRect(
        x: min(max(restored.main.maxX + 10, visible.minX), visible.maxX - width),
        y: min(max(restored.main.maxY - height, visible.minY), visible.maxY - height),
        width: width, height: height)
    return NativeWorkspaceTarget(destination: .timezoner, main: restored.main,
        calendar: restored.agenda.frame ?? temporaryAgenda, workspace: nil, restoration: restored)
}

private func prepareContent(for target: NativeWorkspaceTarget) {
    if target.destination == .calendar {
        if presentation.destination != .calendar { prepareCalendar() }
        if let frames = target.workspace {
            updateAttachment { pair.beginWorkspace(frames, applyFrames: false, focusCalendar: false) }
        }
    } else {
        presentation.returnToTimeZoner()
    }
    refreshCalendar()
}
```

`target(for:)` is called before content/destination changes. If entry originated in the normal popover, first position the hidden real agenda panel at a clamped 220 × 580 start frame using the same `temporaryAgenda` clamp formula around the old main frame; then `beginWorkspace(...applyFrames: false)` dismisses the popover and shows that real panel. This avoids a frame-zero flash.

- [ ] **Step 4: Animate both real frames in one native transaction**

Replace user-facing `enterCalendarMode` / `returnToTimeZoner` with `requestTransition(to:)` calls. Add:

```swift
private func requestTransition(to destination: CalendarDestination) {
    if transitionGate.active == nil && presentation.destination == destination { return }
    guard let request = transitionGate.begin(to: destination) else { return }
    guard let target = target(for: destination) else {
        _ = transitionGate.cancel()
        return
    }
    activeNativeTarget = target
    pair.setTransitionInProgress(true)
    presentation.isWorkspaceTransitioning = true
    mainPanel.persistsNormalPosition = false
    closeOwnedPopovers()
    let motion = CalendarWorkspaceMotion(
        reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    withAnimation(.easeOut(duration: motion.fadeOut)) {
        presentation.workspaceContentOpacity = 0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + motion.fadeOut) { [weak self] in
        guard let self, self.transitionGate.isCurrent(request.id) else { return }
        self.prepareContent(for: target)
        self.presentation.workspaceContentOffset = destination == .calendar ? motion.travel : -motion.travel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = motion.move
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.mainPanel.animator().setFrame(target.main, display: true)
            self.agendaPanel.animator().setFrame(target.calendar, display: true)
        } completionHandler: { [weak self] in
            guard let self, self.transitionGate.isCurrent(request.id) else { return }
            self.completeFrames(target, focus: false)
            withAnimation(.easeOut(duration: motion.fadeIn)) {
                self.presentation.workspaceContentOpacity = 1
                self.presentation.workspaceContentOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + motion.fadeIn) { [weak self] in
                guard let self, self.transitionGate.isCurrent(request.id) else { return }
                let next = self.transitionGate.finish(request.id)
                self.activeNativeTarget = nil
                self.presentation.isWorkspaceTransitioning = false
                self.pair.setTransitionInProgress(false)
                self.mainPanel.persistsNormalPosition = destination == .timezoner
                self.focusCompletedTarget(destination)
                if let next { self.requestTransition(to: next) }
            }
        }
    }
}
```

Use the toolchain's main-actor requirements consistently: the coordinator and SwiftUI state are main-thread-only. If the SDK marks a completion closure nonisolated, hop with `Task { @MainActor in ... }` before reading the gate, and perform the token check inside that hop. Do not bypass isolation with unchecked Sendable conformances.

Add an optional `focusMain: Bool = true` parameter to `CalendarPanelPairController.endWorkspace`, and guard its final `main.focus()` with that flag. Then implement the two helpers used above:

```swift
private func completeFrames(_ target: NativeWorkspaceTarget, focus: Bool) {
    updateAttachment {
        if let frames = target.workspace {
            pair.beginWorkspace(frames, applyFrames: true, focusCalendar: focus)
        } else if let restored = target.restoration {
            pair.endWorkspace(restored, showAgenda: presentation.showAgendaWing, focusMain: focus)
            savedNormalLayout = nil
        }
    }
}

private func focusCompletedTarget(_ destination: CalendarDestination) {
    guard mainPanel.isVisible else { return }
    if destination == .calendar {
        agendaPanel.makeKey()
    } else {
        mainPanel.makeKey()
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    }
}
```

Remove CalendarModeView's `.onAppear(perform: refreshActiveInterval)` because the coordinator now owns entry refresh; toolbar range changes still refresh explicitly. No timer controls EventKit fetch timing.

- [ ] **Step 5: Stop native animation and invalidate callbacks on lifecycle interruption**

Use a zero-duration **animator** transaction to replace in-flight frame targets. The local macOS SDK `NSAnimation.h` documents that setting a new animated property value with an `NSAnimationContext` duration of zero stops its in-flight animation. Merely clearing a Swift token or calling a nonanimated frame setter is not the cancellation mechanism.

Implement:

```swift
func settleWorkspaceTransition() {
    guard let destination = transitionGate.cancel() else { return }
    let settled = (activeNativeTarget?.destination == destination)
        ? activeNativeTarget : target(for: destination)
    guard let settled else { return }
    activeNativeTarget = nil
    prepareContent(for: settled)
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0
        mainPanel.animator().setFrame(settled.main, display: true)
        agendaPanel.animator().setFrame(settled.calendar, display: true)
    }
    completeFrames(settled, focus: false)
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        presentation.workspaceContentOpacity = 1
        presentation.workspaceContentOffset = 0
        presentation.isWorkspaceTransitioning = false
    }
    pair.setTransitionInProgress(false)
    mainPanel.persistsNormalPosition = destination == .timezoner
}
```

Call settlement before `hide()` changes visibility and before the existing application-deactivation path. Call it at the start of `restoreTimeZonerImmediately()`; then restore to normal synchronously if settlement left a workspace. A normal explicit deep link must not wait for the animation queue. Call it from notification preparation before showing/selecting/focusing the reference surface.

In `panelFrameChanged`, when `presentation.isWorkspaceTransitioning` is true, ignore ordinary move/resize notifications. A screen-change notification first settles, then recalculates on the connected display. Add a `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` observer on `NSWorkspace.shared.notificationCenter` that settles a running transition. Store/remove that observer using the same notification center that registered it; the existing default-center token array alone cannot remove it.

Guard the hugging delegate callback during the transition; after `completeFrames`, derive both hugging values from each final frame's `maxY` and the current visible top using the existing 30-point threshold. This prevents mid-animation corner flips changing header geometry.

- [ ] **Step 6: Pin focus-protection release and popover-entry behavior**

Append this block to `runCalendarPanelCoordinatorTests()` using its existing fakes:

```swift
do {
    let scheduler = CalendarPanelDeferredSchedulerFake()
    let main = CalendarPanelSurfaceFake(frame: CGRect(x: 200, y: 100, width: 600, height: 500))
    let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
    let popover = CalendarPanelPopoverFake()
    let pair = CalendarPanelPairController(main: main, agenda: agenda, agendaPopover: popover,
        visibleFrame: { visible }, scheduleDeferredDismissal: scheduler.schedule)
    pair.show(showAgenda: true)
    expectCalendarPanel(popover.isPresented, "normal cramped layout starts in a popover")
    pair.setTransitionInProgress(true)
    main.isKey = false
    pair.panelDidResignKey(); scheduler.runAll()
    expectCalendarPanel(main.isVisible, "internal transition focus cannot dismiss the pair")
    let target = CalendarWorkspaceLayout.calculate(main: main.frame, agenda: nil,
        placement: .popover, visibleFrame: visible)
    pair.beginWorkspace(target, applyFrames: true, focusCalendar: false)
    expectCalendarPanel(agenda.isVisible && !popover.isPresented,
                        "workspace promotes the actual calendar panel once")
    pair.setTransitionInProgress(false)
    pair.panelDidResignKey(); scheduler.runAll()
    expectCalendarPanel(!main.isVisible && !agenda.isVisible,
                        "ordinary blur behavior resumes after transition")
}
```

Run `cd app && swift run TimeZonerTests` and `./scripts/build.sh`. Expected: all tests pass; no permission prompt; full app builds.

- [ ] **Step 7: Commit the timeline after native cancellation code is reviewed**

```bash
git add app/Sources/Models/CalendarWorkspaceState.swift app/Sources/Models/CalendarPresentationState.swift app/Sources/App/CalendarPanelCoordinator.swift app/Sources/App/TimeZonerApp.swift app/Sources/Views/ContentView.swift app/Sources/Views/AgendaView.swift app/Sources/Views/CalendarModeView.swift app/Sources/Views/TimeZonerRailView.swift app/Tests/CalendarWorkspaceTransitionTests.swift app/Tests/CalendarPanelCoordinatorTests.swift app/Tests/TimeZonerTests.swift
git commit -m "feat: animate calendar workspace with accessible interruption"
```

### Task 7: Verify the actual installed interaction and document observations

**Files:**
- Create: `docs/verification/calendar-workspace-transition-2026-09-25.md`
- Modify: `README.md` (calendar interaction/defaults)
- Modify implementation files only for concrete defects found during this task; preserve task-level tests and add a meaningful regression when the defect concerns behavior.

**Interfaces:**
- Consumes the built app and all earlier task contracts.
- Produces a verification record with exact tested commit, commands/results, installed/running path, observations/screenshots, and explicitly untested conditions.

- [ ] **Step 1: Run the final automated and package gates once**

```bash
cd app
swift run TimeZonerTests
cd ..
./scripts/build.sh
codesign --verify --deep --strict app/TimeZoner.app
git diff --check
```

Expected: executable suite exits 0; packaged build/signature verification exits 0; diff check has no output. Record actual results, not the prior branch's test count. The layout/chrome change requires visual verification even with passing tests.

- [ ] **Step 2: Install the verified package and launch its explicit path**

When implementation/installation has been authorized, inspect running TimeZoner processes with `ps -axo pid=,command= | rg '/TimeZoner.app/Contents/MacOS/TimeZoner'`. Quit the identified TimeZoner app normally, then:

```bash
./install.sh --skip-build --destination /Users/team/Applications
codesign --verify --deep --strict /Users/team/Applications/TimeZoner.app
open -n /Users/team/Applications/TimeZoner.app
```

Confirm the process executable is `/Users/team/Applications/TimeZoner.app/Contents/MacOS/TimeZoner`. Another same-bundle-ID copy exists under `/Applications`; do not rely on `open -a TimeZoner`. If the rebuild resets Calendar permission, let the user grant it; record the actual permission state and continue with permission-free geometry checks meanwhile.

- [ ] **Step 3: Inspect both end states and interrupt the real animation**

Use the native UI automation surface or manual interaction, without changing production calendar events:

1. In normal mode, check input/Now/calendar/settings and Agenda/date/expand nav centers, both 20-point insets, matching content-start line, and no second calendar glyph in Agenda.
2. Expand agenda. Verify two actual visible panels, rail on the left, no map/input/add/remove city controls, settings on the right, and the 340 ms transition without nav/title jump.
3. Click a timed event: calendar stays in place, all city times update, long selected title stays in its fixed context slot. Click an all-day event: details open, date/reference time do not change.
4. Click Now: context clears and city times become live; calendar range remains unchanged. Navigate previous/next, Today, 3 Day, Week; jump Today must not change the reference instant.
5. Expand TimeZoner from the rail: exact prior normal frame and normal agenda visibility are restored. Repeat ten times, then invoke Escape midway; neither panel may reappear. Reopen with the global hotkey and check a consistent settled layout.
6. Open settings with the button and `⌘,` from both key panels; transfer focus into event details and between panels. Neither should disappear during an internal transfer. External app focus and Escape retain normal dismissal.
7. Turn Reduce Motion on and repeat. Expect an opacity change with no frame travel, text scaling, or bounce. Restore the user's original system setting afterward if changed with permission.

Record screenshots for both stable states in light and dark modes, plus a short screen recording of the transition if the tooling supports it. Do not claim smoothness from still screenshots alone.

- [ ] **Step 4: Verify boundary layouts and user-intent preservation**

Use isolated test preferences or temporary saved-city changes with restoration, never erase the user's defaults:

- 0, 1, 2, 4, and 8 cities: workspace dimensions stay stable, all rail cards remain reachable, returning uses correct normal width.
- Normal right agenda, normal left agenda, and normal agenda popover: each expands to one real calendar window; return restores the appropriate normal presentation.
- 800-point and 500-point visible-frame fixtures: side-by-side/stacked fallback, compact toolbar, and horizontal week grid remain reachable. Pure tests supply geometry if actual display sizes cannot reproduce these cases; mark native checks untested in that case.
- Drag either panel: pair gap/top alignment remains stable. Move across screens or disconnect a display only if the user has such a setup available; otherwise preserve that manual row as untested.
- Fresh isolated preferences with no access show explanation without a prompt; explicitly hidden stays hidden after reopening. Permission loss, if the user elects to test it, leaves recovery in the full calendar rather than collapsing or showing old events.
- A `timezoner://set` command for a missing city returns to normal, adds the city, and fits the new width. Notification activation while workspace is open selects/focuses the rail and keeps the workspace. Use existing fake-router tests if triggering a real scheduled notification is impractical; do not fabricate a native pass.

- [ ] **Step 5: Write the verification record and concise README behavior**

Start the record with these exact sections, filling each with observed commands/results rather than promised outcomes:

```markdown
# Calendar workspace verification — 2026-09-25

## Build under test

Commit, macOS version, installed executable path, signature verification result.

## Automated checks

Test command, actual passed/failed counts, build result, diff check.

## Native observations

Observed layouts, focus, selection, motion, interruption, and screenshots/recording paths.

## Conditions not exercised

Specific unavailable hardware, permission, notification, or accessibility checks and why.
```

Update README's Calendar section to say: agenda visible by default when unset; calendar button hides/shows it; expand Agenda opens the week/range workspace with stacked city times; expand TimeZoner returns; timed selection remains in the calendar workspace; settings belongs to the large panel. Preserve read-only access, local data, and notification caveats.

Run `git diff --check`. Commit only relevant documentation and any separately tested fix:

```bash
git add README.md docs/verification/calendar-workspace-transition-2026-09-25.md
git commit -m "docs: record calendar workspace verification"
```

## Plan self-review record

- Spec coverage: normal defaults/access (Task 1), pair geometry/restoration (Task 2), common chrome/settings (Task 3), rail/toolbar/icons/in-place event selection (Task 4), native ownership/focus/routing (Task 5), motion/interruption/Reduce Motion (Task 6), real rendering/edge cases/evidence (Task 7).
- Placeholder scan: all implementation steps contain concrete interfaces, code or exact existing-code transformations, test actions, and commands. Manual observations intentionally remain unchecked until execution.
- Type consistency: all new public types/functions are defined in their producing tasks; existing types are identified in Interfaces; coordinator helpers are defined in Tasks 5–6. The optional `focusMain` addition in Task 6 extends the Task 5 method rather than introducing a second restoration API.
- Review Focus coverage: all five listed classes have deterministic tests in their owning tasks; native timing, screen changes, and settings/window integration also have explicit real-app checks.
- Scope: one coordinated UI plan; no calendar mutation/provider rewrite, hidden new authentication, or notification scheduling expansion.

## Execution handoff

Review the spec and plan before implementation, as required by the writing-plans skill. The previously chosen execution method remains subagent-driven development with Terra xhigh building agents and fresh reviewers. This document is the reviewable result of the requested Astra planning pass; no app code or installed binary was changed while writing it.
