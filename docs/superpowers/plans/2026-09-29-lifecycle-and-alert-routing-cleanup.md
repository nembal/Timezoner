# Lifecycle and Alert Routing Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retain application delegates, reschedule wall-clock work correctly, and collapse duplicate alert-routing callbacks without changing TimeZoner behavior.

**Architecture:** Keep AppKit ownership in `TimeZonerApp`, time boundaries in `CalendarClock`, and calendar cache triggers in `CalendarStore`. Expose one alert-input callback rather than making three equivalent callbacks cross the app boundary.

**Tech Stack:** Swift 5.9, macOS AppKit, Foundation, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-09-29-full-repository-cleanup-design.md`

## Global Constraints

- Preserve deep-link, status-item, hotkey, and read-only Calendar behavior.
- Keep all changes local; no install, restart, push, or release.
- Test first; run `cd app && swift run TimeZonerTests` and `git diff --check` before commit.

## Review Focus

- A local `NSApplicationDelegate` must remain alive throughout `app.run()`.
- A timezone or system-clock change must recalculate next wall-clock boundary deadlines.
- Provider, hourly, and timezone CalendarStore changes must each still request reconciliation exactly once.

---

### Task 1: Delegate, clock, and alert-input lifecycle

**Files:**
- Modify: `app/Sources/App/TimeZonerApp.swift`, `app/Sources/Utilities/CalendarClock.swift`, `app/Sources/Stores/CalendarStore.swift`
- Modify: `app/Tests/TimeZonerLaunchTests.swift`, `app/Tests/CalendarClockTests.swift`, `app/Tests/CalendarStoreTests.swift`

**Interfaces:**
- Produces one `CalendarStore` alert-input callback, invoked for provider, hour, and timezone changes.
- Produces explicit delegate lifetime ownership across `NSApplication.run()`.

- [ ] Write failing tests for delegate-owner lifetime through the smallest launch seam; timezone/system-clock rescheduling of pending clock boundaries; and one reconciliation request for each CalendarStore alert-input trigger.
- [ ] Run the focused executable tests and confirm they fail for absent lifetime/reschedule/unified-callback behavior.
- [ ] Implement explicit delegate retention; reschedule the stored boundary timers after timezone or wall-clock notifications; replace three equivalent CalendarStore callback properties with `onAlertInputsChanged` and wire it once in `TimeZonerApp`.
- [ ] Run `cd app && swift run TimeZonerTests` and `git diff --check`.
- [ ] Commit only these files with a lifecycle-focused message.
