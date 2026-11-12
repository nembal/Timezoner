# Calendar workspace verification — 2026-09-25

## Build under test

- Source commits: `6bb4f01` (`fix: retain calendar workspace panel size`), `3bb3004bbc74d2da1a8bf9448b44c4a3678d9f87` (`fix: hide calendar range picker labels`), and `2e00c7ab35f93df25b04a56b4b18b787a7a874c2` (`fix: settle calendar transitions for external changes`). The source tree built, installed, and inspected matched these commits; this record is committed separately.
- Host: macOS 26.6.2 (25G83), arm64.
- Installed executable: `/Users/team/Applications/TimeZoner.app/Contents/MacOS/TimeZoner`.
- Installation: after inspecting identified TimeZoner processes, attempted normal Quit. Windowless orphan instances did not terminate, so only their recorded TimeZoner PIDs received graceful `TERM` before running `./install.sh --skip-build --destination /Users/team/Applications`, verifying the installed bundle signature, and finally running `open -n /Users/team/Applications/TimeZoner.app`.
- Process verification: the final launch was checked by exact executable path, not app name. After restoring the original `Show agenda = false` preference, it was `60905 /Users/team/Applications/TimeZoner.app/Contents/MacOS/TimeZoner`.
- Installed signature: `codesign --verify --deep --strict /Users/team/Applications/TimeZoner.app` exited 0.

## Automated checks

| Command | Actual result |
| --- | --- |
| `cd app && swift run TimeZonerTests` | 777 passed, 0 failed; exit 0. Includes the panel-host, picker-accessibility, deep-link-entry, and current-display-restoration regressions. |
| `./scripts/build.sh` | Production build completed; `TimeZoner.app` ad-hoc signed. |
| `codesign --verify --deep --strict app/TimeZoner.app` | Exit 0, no diagnostic output. |
| `git diff --check` | Exit 0, no output. |

## Native observations

- An initial pre-fix capture showed the access explanation and **Enable Calendar Access** control without requesting permission; that button was not activated. In the final installed-app recheck, existing EventKit-local read access refreshed and rendered local all-day rows plus read-only calendar controls. No access button or privacy control was activated, and no calendar event was created, changed, or deleted.
- With a temporary, restored `Show agenda` preference, the compact companion was a real 220 × 580 native window adjacent to the normal 768 × 580 TimeZoner panel. Its header exposed only `Friday, Sep 25` and **Expand calendar**: no `Agenda` title or duplicate calendar glyph was present.
- Expanding produced two real native windows: a 240 × 580 rail and a 760 × 580 full calendar. The rail retained its stacked, neutral city cards and explicit **Expand TimeZoner** return control. Returning restored the normal TimeZoner surface and compact companion.
- The full calendar settings gear opened the same settings popover. The normal-panel gear was also observed. The observed captures retain the existing neutral cards, controls, typography, borders, spacing, and map styling.
- A typed `11:30am SF` changed the city values and the seven interior three-hour map labels from `01 04 07 10 13 16 19` to `09 12 15 18 21 00 03`; **Now** restored the live city values and label sequence. The neutral day/night overlay remained visible and city dots remained legible.
- A native-QA defect was found and repaired under Task 7's concrete-defect allowance. Before the repair, expanding with Calendar access unavailable left the calendar panel at 760 × 1904 while the coordinator's frame target was 760 × 580, leaving a large blank area. The cause was an unconstrained bare `NSHostingView` adopting the full calendar root's intrinsic size. `CalendarPanelHosting.fixed` sets the reviewed initial host size and clears `sizingOptions`; after rebuilding/reinstalling, the native window report was exactly rail 240 × 580 and calendar 760 × 580. `CalendarPanelHostTests` is the focused regression for the fixed hosting policy.
- The final light and dark full-workspace captures show the normal 40-point one-line toolbar order—Today/3 Day/Week, previous, date, next, Today, settings—with no visible **Calendar range** label. The control retains the explicit **Calendar range** VoiceOver name and its Day/Three day/Week options. The focused `CalendarAccessibilityTests` regression protects that semantic label.
- Two final-review lifecycle races were repaired under the same Task 7 concrete-defect allowance. External deep links now always synchronously ask the native owner to settle/restore TimeZoner before applying, even while the value destination still reads TimeZoner during calendar entry; `TimeZonerDeepLinkTests` proves restore-before-apply for that state. Transition settlement also rebuilds its target from the saved normal snapshot against the current visible display rather than a cached native target; `CalendarPanelCoordinatorTests` proves a removed-display normal return reclamps before its snapshot is cleared.
- Stable-state captures (committed repository paths):
  - `docs/verification/screenshots/calendar-workspace-normal-light-final.png`
  - `docs/verification/screenshots/calendar-workspace-compact-light-final.png`
  - `docs/verification/screenshots/calendar-workspace-rail-light-fixed.png`
  - `docs/verification/screenshots/calendar-workspace-full-light-fixed.png`
  - `docs/verification/screenshots/calendar-workspace-normal-dark-final.png`
  - `docs/verification/screenshots/calendar-workspace-compact-dark-final.png`
  - `docs/verification/screenshots/calendar-workspace-rail-dark-fixed.png`
  - `docs/verification/screenshots/calendar-workspace-full-dark-fixed.png`
- A short transition recording was not available from the native automation surface.

The Task 7 prose asks for eight visible three-hour map labels. The approved Task H contract and implementation deliberately render seven interior labels (indices 3, 6, 9, 12, 15, 18, and 21), omitting the date-line seam. This record reports the implemented, tested seven-label behavior; no eighth label was added.

## Conditions not exercised

- No real timed/all-day event selection, event-details focus transfer, calendar-range navigation, or per-calendar filtering was exercised. Existing local all-day rows were only rendered; no event was created, changed, or deleted.
- The automation surface could focus the compact and full panels but could not reliably inject Escape during the 340 ms native transition; repeated-expansion, mid-animation Escape, external-app blur, and global-hotkey checks remain untested rather than passed.
- Reduce Motion was not changed, so its opacity-only transition behavior remains untested. The original app appearance setting (`System`) was restored after temporary light/dark capture.
- The real saved-city list was not changed. Native 0/1/2/8-city cases, narrow 800/500-point displays, compact toolbar/grid scrolling, left/popover placement, pair dragging, and display removal/multi-display movement remain covered by deterministic tests but are untested on this host.
- `timezoner://set` with a missing city and real notification activation were not invoked, to avoid altering the user's city list or fabricating a notification result.
- The original explicit `Show agenda = false` and `System` appearance preferences were recorded before temporary layout QA and are restored after the final relaunch. No Calendar permissions were requested or altered, and no user defaults were erased.
