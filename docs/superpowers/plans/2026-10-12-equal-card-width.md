# TimeZoner Equal Card Width Implementation Plan

Make the main TimeZoner cards equally wide so Bangkok, New York, and Budapest remain readable. Adding a fifth city should widen the main panel instead of shrinking the existing cards. This plan proposes a 200 point card width, with visual verification before considering the change complete.

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task. Steps use checkboxes for tracking.

**Goal:** Readable city names on equal width cards, with panel growth when cities are added.

**Architecture:** Share the horizontal card width between panel sizing and the card collection. Keep calendar positioning under the existing panel coordinator, which already supports placing the agenda on either side or showing it as a popover.

**Tech stack:** SwiftUI, AppKit, Swift Package Manager, macOS 14 or later, zero new dependencies.

**Spec:** The requirements and acceptance criteria below. The existing calendar companion design remains the integration baseline.

## Requirements and scope

- Main horizontal cards use a shared 200 point width, including card padding. This is the proposed starting size; verify the supplied city names at the existing font sizes.

- Retain the 36 point time difference gaps and 20 point outer insets.

- Four cards produce a 948 point main panel; five produce 1184 points. Adding one city increases width by 236 points.

- Preserve the existing minimum panel width policy for zero or one city, using a minimum count of two in the panel formula.

- Remove the ellipsis menu entirely. Edit by clicking the time, reorder by dragging, and remove with the hover-only top-right overlay. Preserve compact vertical spacing and accessibility actions.

- Keep the vertical city rail in calendar mode flexible at its existing width.

- Preserve time editing, highlighting, drag ordering, selected event context, and map expansion.

- When the agenda cannot fit beside the main panel, retain its opposite side or popover fallback.

- Scope is the existing calendar companion checkout at `/Users/team/dev/worktrees/Timezoner/codex-calendar-companion`, branch `codex/calendar-companion`. Inspect its current status before implementation and preserve unrelated work. Use Worktrunk if another isolated checkout becomes necessary.

## Current layout findings

`app/Sources/Models/CalendarWorkspaceContracts.swift` calculates the normal panel width with 155 points per card. `app/Sources/Views/ZoneCardCollection.swift` allows cards to flex across that width. The available city label space must also accommodate horizontal padding and the GMT offset.

The screenshot shows an inline action menu competing with the city name. The inspected calendar checkout already includes a separate action row for cards below 240 points in `app/Sources/Views/ZoneCard.swift`. Validate the build used for visual checks so the screenshot and tested implementation are comparable.

`ContentView` already requests resizing when the city count changes. `CalendarPanelPairController.resizeMain(to:showAgenda:)` preserves the main panel top edge and refreshes agenda placement.

## Task 1 Set equal card widths and panel growth

**Files:** Modify `app/Sources/Models/CalendarWorkspaceContracts.swift`, `app/Sources/Views/ZoneCardCollection.swift`, and `app/Tests/CalendarWorkspaceContractsTests.swift`.

**Interfaces:** Add `CalendarPanelMetrics.normalCardWidth: CGFloat = 200` and `CalendarPanelMetrics.normalCardGap: CGFloat = 36`. Preserve `normalWidth(cityCount: Int) -> CGFloat`. Apply the fixed width only to horizontal cards; vertical cards remain flexible.

- [ ] Update contract assertions to expect normal panel widths of 476 for zero, one, and two cities; 948 for four cities; and 1184 for five cities. Assert the four to five city increment is 236. Update the expanded map size assertion to `CGSize(width: 948, height: 580)`.

- [ ] Run `swift run TimeZonerTests` from `app/` and confirm the new width assertions fail against the old formula. If using the CLT toolchain, first run `bash fix-spm.sh`, then run `SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh swift run TimeZonerTests`.

- [ ] Change `normalWidth(cityCount:)` to use the shared card width, gap, and horizontal inset values. Apply `normalCardWidth` to horizontal cards in `ZoneCardCollection`; use `normalCardGap` for horizontal offset labels and drag slot calculations. Leave vertical sizing and vertical drag gaps unchanged.

- [ ] Run the test runner again. Require zero failures, including existing ordering and header layout tests.

- [ ] Review and commit only the changes belonging to this task.

## Task 2 Verify readable headers and calendar placement

**Files:** Extend `app/Tests/ZoneCardOrderingTests.swift` and `app/Tests/CalendarPanelCoordinatorTests.swift` using their existing test helpers. Inspect `app/Sources/Views/ZoneCard.swift`, `app/Sources/Models/CalendarPanelPairController.swift`, and `app/Sources/Models/CalendarPresentationState.swift` if verification reveals a regression.

**Interfaces:** Consume the metrics from Task 1 and the existing `resizeMain(to:showAgenda:)` and `AgendaPlacementCalculator.calculate(mainFrame:visibleFrame:wingSize:)` interfaces.

- [ ] Verify direct time editing, drag reordering, and the hover-only top-right remove overlay; remove superseded action-row assertions.

- [ ] Add coordinator cases that resize from four to five cities and back, asserting the requested main width, preserved top edge, and recalculated agenda location. Cover right side, left side, and neither side fitting, where the agenda uses the popover fallback.

- [ ] Run the test runner and require zero failures. Fix only regressions introduced by the width change.

- [ ] Build with `./build.sh` and open that checkout's `app/TimeZoner.app` for visual checks. Avoid confusing it with an older installed build.

- [ ] Verify Bangkok, SF, New York, and Budapest have equal 200 point cards and fully readable names. Add a fifth city and confirm existing widths stay constant as the panel grows; remove it and confirm the panel shrinks.

- [ ] Check editing, drag ordering, map expanded and collapsed states, agenda visibility, and returning from calendar mode. Verify the hover remove overlay appears consistently and the vertical rail remains usable.

- [ ] Check the main panel near both screen edges. If it would extend outside the visible screen, record and resolve the intended overflow behavior before shipping; do not silently shrink the cards to hide the issue.

- [ ] Review and commit the focused verification changes.

## Review focus and completion criteria

Five conditions need explicit review: long city labels with GMT offsets; four to five city growth; zero or one city sizing; agenda placement near screen edges; and returning from calendar mode after changing cities. Contract tests cover numeric sizing and placement, while visual checks cover label readability, equal rendered widths, and calendar transitions.

The change is ready when the test runner has zero failures and the four and five card visual checks pass. Names longer than the target examples may still truncate; if 200 points fails the target examples, adjust the single shared width and matching expectations together. When the main panel cannot fit, cap its width to the visible display and scroll the fixed-width row. Highlighted conversion targets must be brought into view.

The compact no-menu layout at f10be23 passed 933 tests with zero failures and built successfully. It is installed and running at ~/Applications/TimeZoner.app. Native four-city and five-city inspection confirmed readable labels and window growth without shrinking existing cards; the original four cities and expanded map were restored. Native hover and drag acceptance remains incomplete. The requested review identified missing automatic reveal of off-screen conversion targets; ba79e89 fixes it with stable card IDs, deterministic selection, and repeat/layout reveal triggers. All 939 tests pass, including five real hosted scroll regressions. Scoped re-review found no blocking defects, and the rebuilt app is installed and running. No push, merge, or release performed.

## Implementation decisions

- Use subagent-driven execution, following the user's selection after this plan was saved.
- User correction: the separate action row made the cards vertically loose. Remove the ellipsis menu completely and restore the hover-only top-right remove overlay; remove the now-unused width-driven header machinery.
- Clamp normal panel placement to the visible display. If the desired panel width exceeds the visible display, cap the window width and allow horizontal scrolling of the fixed-width row. Cards keep their width; the map and toolbar use the available window width.
- Review this plan's changes from commit 2e8c91d. Preserve the pre-existing calendar branch, checkout, and all earlier work.
