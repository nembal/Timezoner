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
