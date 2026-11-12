# Workspace Structure Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove proven one-callsite indirection and duplicate workspace geometry literals while preserving transition behavior.

**Architecture:** Keep pure metrics and layout policy as the source of geometry. Put short synchronous call ordering directly in `CalendarPanelCoordinator`, where native panel ownership already lives.

**Tech Stack:** SwiftUI/AppKit, Foundation, custom executable tests.

**Spec:** `docs/superpowers/specs/2026-09-29-full-repository-cleanup-design.md`

## Global Constraints

- Preserve workspace frames, transition generation behavior, focus ordering, and selected-event reference-time behavior.
- Do not alter native animation timing or panel visibility policy.
- Test first; run `cd app && swift run TimeZonerTests` and `git diff --check` before commit.

## Review Focus

- Geometry remains identical for normal, constrained, and fallback workspace layouts.
- Return-to-TimeZoner still keys the main panel before posting chat focus.
- Event activation still selects the reference instant with the current source timezone.

---

### Task 1: Metric ownership and one-callsite removal

**Files:**
- Modify: `app/Sources/Models/CalendarPanelPairController.swift`, `app/Sources/Models/CalendarWorkspaceLayout.swift`, `app/Sources/App/CalendarPanelCoordinator.swift`, `app/Sources/Views/CalendarModeView.swift`, `app/Sources/Models/CalendarWorkspaceRailPresentation.swift`, `app/Sources/Models/CalendarWorkspaceSession.swift`
- Modify: `app/Tests/CalendarWorkspaceLayoutTests.swift`, `app/Tests/CalendarPanelCoordinatorTests.swift`, `app/Tests/CalendarWorkspaceRailTests.swift`

**Interfaces:**
- Consumes existing `CalendarPanelMetrics` and `AgendaPlacementCalculator` constants.
- Leaves `ReferenceMomentController.selectEvent` as the event-selection authority.

- [ ] Write failing geometry/focus/event-selection regressions that express the existing output/order without asserting implementation types.
- [ ] Run focused tests and confirm they fail once the direct metric/call-order seam is introduced.
- [ ] Replace copied dimensions with named metrics; inline only proven one-callsite synchronous wrappers in the coordinator/view; delete obsolete wrapper tests/types.
- [ ] Run `cd app && swift run TimeZonerTests` and `git diff --check`.
- [ ] Commit only this workspace-structure batch.
