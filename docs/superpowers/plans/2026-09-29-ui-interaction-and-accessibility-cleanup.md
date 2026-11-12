# UI Interaction and Accessibility Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove stale shared-card interaction state and fill concrete accessibility gaps without redesigning TimeZoner surfaces.

**Architecture:** Keep shared zone-card rendering intact. Move highlight timing to one owner, refresh measured drag size when layout changes, and add labels/values/actions to existing controls rather than inventing alternate flows.

**Tech Stack:** SwiftUI, AppKit accessibility, Foundation, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-09-29-full-repository-cleanup-design.md`

## Global Constraints

- Preserve shared horizontal/vertical `ZoneCardCollection -> ZoneCard` behavior.
- Keep map interactions and calendar semantics unchanged.
- Test first; run `cd app && swift run TimeZonerTests` and `git diff --check` before commit.

## Review Focus

- A card action-row height change cannot leave vertical drag slot measurement stale.
- A newer highlight survives an older delayed clear.
- Calendar events on different dates remain distinguishable to assistive technology.
- Every keyboard-focusable custom control exposes its state and purpose.

---

### Task 1: Card measurement, shared highlighting, and accessible context

**Files:**
- Modify: `app/Sources/Views/ZoneCardCollection.swift`, `app/Sources/Views/ChatField.swift`, `app/Sources/Views/ContentView.swift`, `app/Sources/Views/CalendarTimeGrid.swift`, `app/Sources/Views/HotkeyRecorderField.swift`, `app/Sources/Views/TimezoneMapView.swift`, `app/Sources/Views/SettingsPopover.swift`
- Modify/create: focused view-model or interaction tests using existing executable-test seams

**Interfaces:**
- Produces a current card-size observation used by drag ordering.
- Produces one cancellable zone-highlight owner consumed by chat and deep-link conversion paths.

- [ ] Write failing tests for a resized vertical card's drag slot, overlapping highlight clear requests, date-qualified calendar labels, and accessible map/shortcut/settings metadata through real helper/state seams.
- [ ] Run focused tests and confirm they fail for the current stale/duplicated behavior.
- [ ] Update card geometry observation on size changes; centralize highlight scheduling/cancellation; add date and state metadata to the existing controls without changing their actions.
- [ ] Run `cd app && swift run TimeZonerTests` and `git diff --check`.
- [ ] Commit only this UI/accessibility batch.
