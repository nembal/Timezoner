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

func runCalendarPanelCoordinatorTests() {
    print("Running CalendarPanelCoordinatorTests...")

    let visible = CGRect(x: 0, y: 0, width: 1_000, height: 800)

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
}
