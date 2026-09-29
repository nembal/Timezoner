import Foundation
import TimeZonerLib

private final class CalendarPanelSurfaceFake: CalendarPanelSurface {
    enum Operation: Equatable {
        case show
        case hide
        case focus
        case setFrame(CGRect)
    }

    var frame: CGRect
    var isVisible = false
    var isKey = false
    private(set) var operations: [Operation] = []

    init(frame: CGRect) {
        self.frame = frame
    }

    func show() {
        isVisible = true
        operations.append(.show)
    }

    func hide() {
        isVisible = false
        isKey = false
        operations.append(.hide)
    }

    func focus() {
        isKey = true
        operations.append(.focus)
    }

    func setFrame(_ frame: CGRect) {
        self.frame = frame
        operations.append(.setFrame(frame))
    }
}

private final class CalendarPanelPopoverFake: CalendarPanelPopoverSurface {
    private(set) var isPresented = false
    var isFocused = false
    private(set) var showCount = 0
    private(set) var dismissCount = 0
    private(set) var focusCount = 0

    func show() {
        isPresented = true
        showCount += 1
    }

    func dismiss() {
        isPresented = false
        dismissCount += 1
    }

    func focus() {
        isFocused = true
        focusCount += 1
    }
}

private final class CalendarPanelDeferredSchedulerFake {
    private(set) var scheduled: [() -> Void] = []

    func schedule(_ work: @escaping () -> Void) {
        scheduled.append(work)
    }

    func runAll() {
        let pending = scheduled
        scheduled = []
        pending.forEach { $0() }
    }
}

private func expectCalendarPanel(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label)")
    }
}

@MainActor
func runCalendarPanelCoordinatorTests() {
    print("Running CalendarPanelCoordinatorTests...")

    let visible = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    do {
        let suiteName = "CalendarPanelTransitionDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)
        expectCalendarPanel(presentation.workspaceContentOpacity == 1,
                            "workspace content starts fully visible")
        expectCalendarPanel(presentation.workspaceContentOffset == 0,
                            "workspace content starts without travel offset")
        expectCalendarPanel(!presentation.isWorkspaceTransitioning,
                            "workspace content starts interactive")
    }

    do {
        let main = CGRect(x: 300, y: 100, width: 400, height: 500)
        let result = AgendaPlacementCalculator.calculate(
            mainFrame: main,
            visibleFrame: visible,
            wingSize: CGSize(width: 220, height: 580)
        )

        expectCalendarPanel(result.location == .right, "uses the right side when it has at least 230 points")
        expectCalendarPanel(result.frame?.minX == 710, "right wing leaves a 10-point gap")
        expectCalendarPanel(result.frame?.maxY == main.maxY, "right wing top-aligns with the main panel")
    }

    do {
        let main = CGRect(x: 700, y: 100, width: 250, height: 500)
        let result = AgendaPlacementCalculator.calculate(
            mainFrame: main,
            visibleFrame: visible,
            wingSize: CGSize(width: 220, height: 580)
        )

        expectCalendarPanel(result.location == .left, "falls back to the left when right space is insufficient")
        expectCalendarPanel(result.frame?.minX == 470, "left wing leaves a 10-point gap")
    }

    do {
        let main = CGRect(x: 200, y: 100, width: 600, height: 500)
        let result = AgendaPlacementCalculator.calculate(
            mainFrame: main,
            visibleFrame: visible,
            wingSize: CGSize(width: 220, height: 580)
        )

        expectCalendarPanel(result.location == .popover, "uses the popover fallback when neither side has 230 points")
        expectCalendarPanel(result.frame == nil, "popover fallback has no off-screen wing frame")
    }

    do {
        let main = CGRect(x: 20, y: 700, width: 300, height: 200)
        let result = AgendaPlacementCalculator.calculate(
            mainFrame: main,
            visibleFrame: visible,
            wingSize: CGSize(width: 220, height: 580)
        )

        expectCalendarPanel(result.frame?.minY == 220, "clamps the wing to the visible frame vertically")
        expectCalendarPanel(result.frame?.maxY == visible.maxY, "clamped wing remains within the visible frame")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        coordinator.show(showAgenda: true)
        expectCalendarPanel(main.isVisible && agenda.isVisible, "show orders the main and attached agenda together")
        expectCalendarPanel(main.isKey, "show focuses the main surface")

        let mainCenter = main.frame.midX
        coordinator.resizeMain(to: CGSize(width: 500, height: 500))
        expectCalendarPanel(main.frame.width == 500, "resizeMain changes the explicit main surface")
        expectCalendarPanel(main.frame.midX == mainCenter, "resizeMain retains the main surface center")
        expectCalendarPanel(main.frame.maxY == 600, "resizeMain retains the main surface top edge")
        expectCalendarPanel(agenda.frame.maxY == main.frame.maxY, "resizeMain recomputes agenda attachment")

        coordinator.hide()
        expectCalendarPanel(!main.isVisible && !agenda.isVisible, "hide orders both panel surfaces out")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 200, y: 100, width: 600, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        coordinator.show(showAgenda: true)
        expectCalendarPanel(main.isVisible && !agenda.isVisible && popover.isPresented, "popover fallback keeps the agenda panel out")
    }

    do {
        let scheduler = CalendarPanelDeferredSchedulerFake()
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 200, y: 100, width: 600, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible },
            scheduleDeferredDismissal: scheduler.schedule
        )

        coordinator.show(showAgenda: true)
        main.isKey = false
        popover.isFocused = true
        coordinator.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(main.isVisible && popover.isPresented, "a focused fallback popover keeps the pair visible")

        popover.isFocused = false
        coordinator.applicationDidResignActive()
        scheduler.runAll()

        expectCalendarPanel(!popover.isPresented, "an unfocused fallback popover closes after app deactivation")
        expectCalendarPanel(!main.isVisible && !agenda.isVisible, "app deactivation does not leave an unfocused fallback pair visible")
    }

    do {
        let scheduler = CalendarPanelDeferredSchedulerFake()
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible },
            scheduleDeferredDismissal: scheduler.schedule
        )

        coordinator.show(showAgenda: true)
        main.isKey = false
        agenda.isKey = true
        coordinator.panelDidResignKey()
        coordinator.panelDidResignKey()
        expectCalendarPanel(scheduler.scheduled.count == 1, "duplicate resignations coalesce into one dismissal check")
        scheduler.runAll()
        expectCalendarPanel(main.isVisible && agenda.isVisible, "main-to-agenda focus transfer keeps the pair visible")

        agenda.isKey = false
        coordinator.setOwnedPopoverPresented(true)
        coordinator.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(main.isVisible, "owned settings or attendee popover keeps the pair visible")

        coordinator.setOwnedPopoverPresented(false)
        expectCalendarPanel(scheduler.scheduled.count == 1, "closing the last owned popover schedules a focus recheck")
        scheduler.runAll()
        expectCalendarPanel(!main.isVisible && !agenda.isVisible, "pair hides only when no panel or owned popover has focus")
    }

    do {
        let suiteName = "CalendarPanelCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let scheduler = CalendarPanelDeferredSchedulerFake()
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible },
            scheduleDeferredDismissal: scheduler.schedule
        )
        let presentation = CalendarPresentationState(defaults: defaults)
        let timeState = TimeState()
        let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)
        timeState.referenceDate = referenceDate
        timeState.isLive = false
        let allDayDetailTarget = CalendarEventDetailPopoverTarget(
            eventID: "all-day-details",
            presenterID: "calendar-grid:all-day-details"
        )

        coordinator.show(showAgenda: false)
        main.isKey = false
        CalendarEventDetailPopoverOwnership.update(
            target: allDayDetailTarget,
            presentation: presentation,
            onOwnedPopoverChanged: coordinator.setOwnedPopoverPresented
        )
        coordinator.panelDidResignKey()
        scheduler.runAll()

        expectCalendarPanel(
            main.isVisible && presentation.eventDetailPopoverTarget == allDayDetailTarget,
            "a targeted calendar all-day detail keeps its host panel visible while the owned popover is open"
        )
        expectCalendarPanel(
            timeState.referenceDate == referenceDate && !timeState.isLive,
            "calendar all-day detail ownership does not mutate the TimeZoner reference moment"
        )

        CalendarEventDetailPopoverOwnership.update(
            target: nil,
            presentation: presentation,
            onOwnedPopoverChanged: coordinator.setOwnedPopoverPresented
        )
        scheduler.runAll()
        expectCalendarPanel(
            !main.isVisible,
            "closing calendar all-day details releases owned-popover protection for normal dismissal"
        )
    }

    do {
        let scheduler = CalendarPanelDeferredSchedulerFake()
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main, agenda: agenda, agendaPopover: popover,
            visibleFrame: { visible }, scheduleDeferredDismissal: scheduler.schedule
        )
        let suiteName = "MapPopoverOwnership.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)

        pair.show(showAgenda: false)
        main.isKey = false
        TimezoneMapPopoverOwnership.setPresented(
            true, presentation: presentation, onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        pair.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(main.isVisible && presentation.hasOwnedPopover,
                            "map zone browser retains its panel while keyboard focus enters the popover")

        CalendarSettingsOwnership.setPresented(
            true, owner: .timezoner, presentation: presentation,
            onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        CalendarSettingsOwnership.setPresented(
            false, owner: .timezoner, presentation: presentation,
            onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        scheduler.runAll()
        expectCalendarPanel(main.isVisible && presentation.hasOwnedPopover,
                            "closing settings does not release a still-open map browser")

        CalendarSettingsOwnership.setPresented(
            true, owner: .timezoner, presentation: presentation,
            onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        TimezoneMapPopoverOwnership.setPresented(
            false, presentation: presentation, onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        scheduler.runAll()
        expectCalendarPanel(main.isVisible && presentation.hasOwnedPopover,
                            "closing the map browser preserves another owned popover")

        CalendarSettingsOwnership.setPresented(
            false, owner: .timezoner, presentation: presentation,
            onOwnedPopoverChanged: pair.setOwnedPopoverPresented)
        scheduler.runAll()
        expectCalendarPanel(!main.isVisible && !presentation.hasOwnedPopover,
                            "closing the last owned popover releases normal focus dismissal")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 200, y: 100, width: 600, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        coordinator.show(showAgenda: true)
        coordinator.handleEscape()
        expectCalendarPanel(!main.isVisible && !agenda.isVisible, "Escape uses the same pair hide path")
        expectCalendarPanel(popover.dismissCount == 1, "Escape closes an owned agenda popover")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        coordinator.show(showAgenda: true)
        main.isKey = false
        expectCalendarPanel(
            coordinator.focusAgenda() == .detachedPanel,
            "a visible detached agenda has an explicit keyboard focus target"
        )
        expectCalendarPanel(agenda.isKey, "keyboard agenda focus moves to the detached wing")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 200, y: 100, width: 600, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        coordinator.show(showAgenda: true)
        main.isKey = false
        expectCalendarPanel(
            coordinator.focusAgenda() == .popover,
            "a visible fallback agenda popover has an explicit keyboard focus target"
        )
        expectCalendarPanel(popover.isFocused && popover.focusCount == 1, "keyboard agenda focus enters the fallback popover")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let coordinator = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        expectCalendarPanel(coordinator.focusAgenda() == nil, "a hidden paired surface does not claim agenda keyboard focus")
        expectCalendarPanel(!agenda.isKey && popover.focusCount == 0, "hidden agenda focus leaves both agenda presentations untouched")
    }

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

    do {
        let scheduler = CalendarPanelDeferredSchedulerFake()
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible },
            scheduleDeferredDismissal: scheduler.schedule
        )

        pair.show(showAgenda: true)
        let normalFrame = main.frame
        main.isKey = false
        agenda.isKey = false
        pair.setTransitionInProgress(true)
        pair.resizeMain(to: CGSize(width: 600, height: 300))
        pair.syncAgendaVisibility(showAgenda: false)
        pair.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(main.frame == normalFrame && main.isVisible && agenda.isVisible,
                            "transition guard preserves a normal pair and its geometry")

        pair.setTransitionInProgress(false)
        pair.syncAgendaVisibility(showAgenda: false)
        expectCalendarPanel(!agenda.isVisible, "normal agenda visibility resumes after a transition")

        pair.resizeMain(to: CGSize(width: 500, height: 400))
        expectCalendarPanel(main.frame.midX == 500 && main.frame.maxY == 600,
                            "normal resize keeps horizontal center and top edge")

        let frames = CalendarWorkspaceLayout.calculate(
            main: main.frame,
            agenda: agenda.frame,
            placement: .right,
            visibleFrame: visible
        )
        pair.beginWorkspace(frames, focusCalendar: false)
        main.isKey = false
        agenda.isKey = false
        pair.show(showAgenda: false)
        expectCalendarPanel(agenda.isKey && agenda.isVisible,
                            "show refocuses the calendar while the workspace is active")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )

        pair.show(showAgenda: true)
        main.isKey = false
        pair.focusTimeZoner()
        expectCalendarPanel(main.isKey, "focusTimeZoner restores focus to a visible main panel")

        var focusOrder: [String] = []
        main.isKey = false
        let priorOperationCount = main.operations.count
        pair.focusTimeZoner(postFocusChat: {
            if main.operations.count > priorOperationCount && main.operations.last == .focus {
                focusOrder.append("makeKey")
            }
            focusOrder.append("focusChat")
        })
        expectCalendarPanel(focusOrder == ["makeKey", "focusChat"],
                            "immediate restoration focuses a visible main panel before requesting chat focus")

        pair.hide()
        pair.focusTimeZoner()
        expectCalendarPanel(!main.isKey, "focusTimeZoner leaves a hidden main panel unfocused")

        focusOrder = []
        pair.focusTimeZoner(postFocusChat: { focusOrder.append("focusChat") })
        expectCalendarPanel(focusOrder == ["focusChat"] && !main.isKey,
                            "hidden restoration still posts chat focus without focusing the panel")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )
        pair.show(showAgenda: false)
        pair.setTransitionInProgress(true)

        var presentationResetBeforePairRelease = false
        pair.finishWorkspaceTransition {
            pair.resizeMain(to: CGSize(width: 550, height: 450), showAgenda: false)
            presentationResetBeforePairRelease = main.frame.size == CGSize(width: 400, height: 500)
        }

        pair.resizeMain(to: CGSize(width: 500, height: 400), showAgenda: false)
        expectCalendarPanel(presentationResetBeforePairRelease,
                            "workspace presentation resets while paired-panel interaction is still gated")
        expectCalendarPanel(
            main.frame.size == CGSize(width: 500, height: 400),
            "releasing the paired-panel interaction gate resumes normal resizing"
        )
    }

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
        pair.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(main.isVisible, "internal transition focus cannot dismiss the pair")

        let target = CalendarWorkspaceLayout.calculate(main: main.frame, agenda: nil,
            placement: .popover, visibleFrame: visible)
        pair.beginWorkspace(target, applyFrames: true, focusCalendar: false)
        expectCalendarPanel(agenda.isVisible && !popover.isPresented,
                            "workspace promotes the actual calendar panel once")

        pair.setTransitionInProgress(false)
        pair.panelDidResignKey()
        scheduler.runAll()
        expectCalendarPanel(!main.isVisible && !agenda.isVisible,
                            "ordinary blur behavior resumes after transition")
    }

    do {
        let main = CalendarPanelSurfaceFake(frame: CGRect(x: 300, y: 100, width: 400, height: 500))
        let agenda = CalendarPanelSurfaceFake(frame: CGRect(x: 0, y: 0, width: 220, height: 580))
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main,
            agenda: agenda,
            agendaPopover: popover,
            visibleFrame: { visible }
        )
        let restored = CalendarWorkspaceRestoration(
            main: main.frame,
            agenda: AgendaPlacementResult(location: .right,
                frame: CGRect(x: 710, y: 20, width: 220, height: 580))
        )

        pair.endWorkspace(restored, showAgenda: false, focusMain: false)
        expectCalendarPanel(!main.isKey,
                            "transition settlement can restore geometry without stealing final focus")
    }

    do {
        let mainFrame = CGRect(x: 300, y: 100, width: 400, height: 500)
        let main = CalendarPanelSurfaceFake(frame: mainFrame)
        let agenda = CalendarPanelSurfaceFake(frame: .zero)
        let popover = CalendarPanelPopoverFake()
        let pair = CalendarPanelPairController(
            main: main, agenda: agenda, agendaPopover: popover, visibleFrame: { visible })
        let restoration = CalendarWorkspaceRestoration(
            main: mainFrame, agenda: AgendaPlacementResult(location: .popover, frame: nil))

        pair.endWorkspace(restoration, showAgenda: false, focusMain: false)
        expectCalendarPanel(agenda.frame == CGRect(x: 710, y: 20, width: 220, height: 580),
                            "popover restoration keeps the hidden agenda panel at its fallback frame")
        expectCalendarPanel(!main.isKey, "geometry restoration does not focus the main panel early")
    }
}
