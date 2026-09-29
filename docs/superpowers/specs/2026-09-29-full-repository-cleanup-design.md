# TimeZoner Full Repository Cleanup

**Status:** Approved for execution, 2026-09-29.

## Goal

Make the current TimeZoner branch suitable for open-source maintenance: correct concrete lifecycle and interaction defects, reduce repeated policy and test plumbing, and make install/release behavior accurately documented. Preserve all existing product features and local-only data boundaries.

## Evidence and scope

Five independent read-only reviews at `c79eaea` found no need for a rewrite. They identified focused defects and duplicated contracts across five independent domains:

1. Application lifecycle and alert routing.
2. SwiftUI interaction and accessibility.
3. Notification contracts and executable-test reliability.
4. Calendar workspace structure and geometry policy.
5. Distribution, Homebrew, packaging, and public documentation.

The work is deliberately divided by file ownership so the five domains can be implemented and reviewed in parallel, then integrated with ordinary Git commits. A batch may change behavior only to correct the reviewed defect; all other simplifications are behavior-preserving.

## Global constraints

- macOS 14+, SwiftUI, AppKit, Swift Package Manager, zero third-party dependencies, and zero network clients remain unchanged.
- Calendar data stays read-only. Do not add accounts, sync, analytics, telemetry, background agents, or new notification categories.
- `TimeState.referenceDate` and `ReferenceMomentController` remain the single conversion-time flow.
- Normal and calendar-rail cards continue to use the shared `ZoneCardCollection -> ZoneCard` path.
- Use Worktrunk worktrees under `/Users/team/dev/worktrees/`; do not use raw `git worktree`.
- Every production change starts with a failing regression test. Each batch runs the full executable suite and `git diff --check` before commit.
- Do not push, publish, release, delete a branch/worktree, or replace/restart the installed app during cleanup without a separate user request.

## Batch A — lifecycle and alert routing

Retain the selected `NSApplicationDelegate` for the full `app.run()` lifetime. Recalculate CalendarClock one-shot wall-clock boundaries after timezone or system-clock changes. Replace CalendarStore's three identical alert-input hooks with one callback while preserving provider/hour/timezone trigger points.

The result must retain deep links, status-item behavior, and notification reconciliation while removing duplicated callback wiring.

## Batch B — shared UI interaction and accessibility

Update card-size observation when a card's compact action row changes layout, so vertical drag thresholds use its current height. Put zone highlighting and cancellation ownership in one coordinator so an earlier delayed clear cannot erase a newer result. Supply missing date/context labels and accessible control metadata for calendar events, map state, shortcut recording, and appearance settings.

The result must preserve pointer and keyboard actions, card reuse, map behavior, and the current panel sizing policy.

## Batch C — notification contracts and test reliability

Define notification request ownership, response payload keys, and lead-time normalization once and reuse them in scheduling, response parsing, adapters, and settings. Repair test doubles whose start signals can be lost, guard async result indexing, remove demonstrably duplicate/misnamed tests, and share repeated clock-signal fixtures without weakening behavior coverage.

The result must preserve pending command parsing and notification identifiers already in circulation.

## Batch D — workspace structural simplification

Replace retyped workspace placement values with `CalendarPanelMetrics`/`AgendaPlacementCalculator` constants. Inline proven one-callsite wrappers around event activation, focus restoration, and transition gate release where call order remains explicit in the coordinator.

The result must keep the existing workspace frames, transition order, and testable pure layout policy.

## Batch E — distribution and documentation hygiene

Treat every replacement of an installed bundle as a guarded lifecycle operation, irrespective of whether `--open` asks for relaunch. Make Homebrew's copied app update path explicit and safe. Bring release-facing documentation into agreement with the currently released v0.3.0 versus current-branch Calendar functionality. Establish one version source for source, Homebrew, and DMG bundles; remove stale packaging examples and brittle version assertions.

The result must not silently replace a running app, imply an unreleased Calendar feature is stable, or leave users unable to identify the installed build version.

## Verification and delivery

Each batch receives an independent read-only review. After integration, run `cd app && swift run TimeZonerTests`, `bash scripts/test-install-lifecycle.sh all`, `./scripts/build.sh`, `codesign --verify --deep --strict app/TimeZoner.app`, `git diff --check`, and a final cross-domain review. Native live checks are recorded as explicitly unverified unless the user separately authorizes installation/relaunch.
