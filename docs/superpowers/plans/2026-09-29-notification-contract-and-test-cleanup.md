# Notification Contract and Test Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate notification identifiers/payload policy and make executable tests deterministic, isolated, and non-misleading.

**Architecture:** Add one small value-only notification contract shared by request scheduling and response parsing. Keep test support local to tests, using stateful signals that cannot lose an already-emitted start event.

**Tech Stack:** Swift Foundation, UserNotifications adapters, custom executable test runner.

**Spec:** `docs/superpowers/specs/2026-09-29-full-repository-cleanup-design.md`

## Global Constraints

- Preserve current notification identifiers and deep-link response payload compatibility.
- Do not weaken meaningful tests or replace behavior checks with implementation-text assertions.
- Test first; run `cd app && swift run TimeZonerTests` and `git diff --check` before commit.

## Review Focus

- Existing scheduled notification IDs remain recognized after contract consolidation.
- A waiter sees a fake operation start whether it waits before or after the operation begins.
- A missed async request reports a test failure rather than trapping the runner.

---

### Task 1: Shared contracts and deterministic test support

**Files:**
- Create: `app/Sources/Models/CalendarNotificationContract.swift`
- Modify: `app/Sources/Utilities/CalendarNotificationScheduling.swift`, `app/Sources/Utilities/UserNotificationCenterAdapter.swift`, `app/Sources/Models/PendingCalendarCommand.swift`, `app/Sources/Stores/SettingsStore.swift`
- Modify: `app/Tests/PendingCalendarCommandTests.swift`, `app/Tests/CalendarProviderTests.swift`, `app/Tests/CalendarClockTests.swift`, `app/Tests/CalendarStoreTests.swift`, `app/Tests/TimeZonerDeepLinkTests.swift`, `app/Tests/ZoneStoreTests.swift`

**Interfaces:**
- Produces `CalendarNotificationContract` as the sole owner of request prefix, payload keys, and lead normalization.
- Produces stateful test start signals and guarded async collection indexing.

- [ ] Write failing compatibility tests for existing request IDs/payloads and start-before-wait signals; add a regression that an absent async result increments failure rather than indexing out of bounds.
- [ ] Run focused tests and confirm the current fake can lose its continuation or the shared contract is absent.
- [ ] Implement the shared contract and replace duplicated literals/normalizers. Repair signals and guards; remove only tests proven redundant or mislabeled; isolate defaults and share duplicated clock fixture plumbing.
- [ ] Run `cd app && swift run TimeZonerTests` and `git diff --check`.
- [ ] Commit only this contract/test batch.
