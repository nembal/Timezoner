# Calendar permission spike — 2026-09-24

## Scope and privacy boundary

This packaged probe verifies only macOS Calendar authorization behavior for the source-built, ad-hoc-signed `TimeZoner.app`. It reads calendar descriptors and a seven-day event count only after full access has been granted. The probe itself has no calendar write operation, network request, account sign-in, or app-owned event/attendee persistence.

The normal application launch does not construct the probe or request Calendar access. The probe is selected only with `--calendar-permission-spike`.

## Non-interactive verification

- `cd app && swift run TimeZonerTests`: passed, `174 passed, 0 failed out of 174 tests`; no Calendar prompt appeared.
- `bash scripts/test-install.sh`: passed; it built, ad-hoc signed, installed to a temporary destination, verified the package resource, and verified the signature.
- `./install.sh`: passed; it built, ad-hoc signed, and restored marker `calendar-permission-probe` at `/Users/team/Applications/TimeZoner.app` without launching it.
- Usage description: `NSCalendarsFullAccessUsageDescription` is set to `TimeZoner reads your calendars to show upcoming events across your saved time zones.`
- Probe marker: `calendar-permission-probe`.

## Human authorization results

Calendar permission changes were performed by a human. Automation did not perform any authorization, revocation, recovery, launch, or UI interaction.

- Initial Calendar grant succeeded. After relaunch, the probe showed a brief loading spinner and then populated both `Calendars: [number]` and `Events in the next 7 days: [number]` with no red fetch error. The exact numeric values were not supplied.
- The changed, re-signed `calendar-probe-b` rebuild at the same installed path retained `Full access` without a new permission prompt.
- Revoking Calendar access produced the denied/recovery state.
- Re-enabling TimeZoner Calendar access in Calendar Privacy and relaunching restored `Full access`.

## Recovery-button visibility follow-up

The always-on-top probe obscured System Settings when `Open Calendar Privacy Settings` was clicked, making the action appear to do nothing. The recovery sequence now orders out the visible `FloatingPanel` before it opens the Calendar privacy URL. `CalendarPermissionRecoveryPlan` has a deterministic pure test for the required order:

- `hideProbe`
- `openCalendarPrivacySettings`

This follow-up is code- and package-verified; it was not clicked after the final rebuild so it did not alter the completed permission observations.

## Observation record

| Check | Observation |
| --- | --- |
| Initial status | Calendar grant succeeded; exact initial probe text was not supplied. |
| Initial real calendar/event fetch | Completed successfully after a brief loading spinner: both `Calendars: [number]` and `Events in the next 7 days: [number]` were populated, with no red fetch error. Exact numeric values were not supplied and are not claimed. |
| Changed-rebuild result | Re-signed `calendar-probe-b` at the same path retained `Full access` without a new prompt. |
| Denial result | Revocation displayed the denied/recovery state. |
| Recovery result | Re-enabling Calendar Privacy access and relaunching restored `Full access`. |
| Initial probe surface | Defect observed: content was drawn over a transparent/no-background panel. Fixed in the `calendar-probe-b` rebuild with an opaque rounded surface. |
| Privacy-settings visibility | Defect observed: floating probe obscured System Settings. Fixed in source by ordering out the probe before opening the URL; not clicked after the final rebuild. |
| Installed path | `/Users/team/Applications/TimeZoner.app` |
| macOS version | macOS 26.6.2 (build 25G83) |
| Prior changed-build designated requirement | `designated => cdhash H"db41145ae6ba8dc5bb260e050b422533e55f8af6"` for the verified `calendar-probe-b` build. |
| Restored-marker designated requirement | `designated => cdhash H"9db2ed51457ca82299bdbc3755f5663cf11eff6a"` for current marker `calendar-permission-probe` build. |

## Gate decision

**DONE_WITH_CONCERNS.** The human observations establish successful grant, a real successful fetch, changed-rebuild persistence without a new prompt, denial, and recovery. The exact real calendar/event count values were not captured, so this document does not claim them. The privacy-settings visibility follow-up is package-tested but awaits an optional visual confirmation on a future manual use.

## Current-branch automated and scope evidence

The following checks ran on 2026-09-24 against final code SHA `528e353` immediately before this evidence-refresh documentation-only commit. They establish deterministic/code and package evidence only; they do not substitute for a native privacy, panel, or notification observation.

| ID | Command or audit | Result | Boundary |
| --- | --- | --- | --- |
| A1 | `cd app && swift run TimeZonerTests` | **558 passed, 0 failed**. | Fakes cover calendar mapping, preferences, presentation, lifecycle, scheduling, and routing; they do not operate macOS permissions or real Calendar data. |
| A1b | Task 9 bounded full-suite stress: 100 consecutive `swift run TimeZonerTests` executions, each bounded to five seconds | **100/100 passed**. | It demonstrates deterministic test stability after the fan-out test repair; it does not operate macOS permissions, Calendar accounts, native panels, or notification delivery. |
| A2–A4 | `./scripts/build.sh`; `codesign --verify --deep --strict app/TimeZoner.app`; packaged PlistBuddy usage-string check | Passed; the build is ad-hoc signed and the usage string exactly matches the source declaration. | Build/signature/plist proof does not establish prompt timing or authorization persistence. |
| A5 | `bash scripts/test-install.sh` | Passed; temporary install, resource-layout, and signature checks completed. | Installer regression coverage only. |
| A6 | `git diff --check` | Passed with no output before the documentation commit. | Whitespace hygiene only. |
| A7 | `rg -n 'EKEventStore|UNUserNotificationCenter' app/Sources` plus allowlist review | `EKEventStore` appears only in `EventKitCalendarProvider`; UserNotifications appears in the adapter, retained delegate, and intentional AppDelegate installation. | A textual boundary audit, not proof of read-only behavior or runtime delivery. |
| A8 | `rg -n 'eventTitle|attendee|startDate|endDate' app/Sources/Stores app/Sources/Models | rg 'UserDefaults|set\\('` | No match; the final `rg` returned its normal no-match exit `1`. | Narrow negative signal only; it does not search every persistence mechanism or field name. |
| A9 | Review `rg -n 'UserDefaults|FileManager|Keychain|CoreData|SQLite|URLSession|NWConnection' app/Sources` | Only normal `UserDefaults` stores were found; no direct network calendar client was found. | The macOS local-notification queue is a separate intentional system-owned boundary described below. |

## Calendar Companion privacy boundary

The agenda and grid use calendar snapshots in memory; TimeZoner does not keep an app-owned event or attendee database. It persists normal settings plus calendar identifier-keyed Show/Alerts preferences and notification lead-time values. Attendee UI uses EventKit-supplied display names; if a provider does not supply a display name, the current mapper can use an address-derived label locally. This record deliberately does not include any actual account, attendee, event-title, or calendar-content values.

Optional alerts are different. When a user enables TimeZoner alerts, macOS retains each eligible occurrence's event title, notification body, occurrence identifier, and start timestamp in its local `UNUserNotificationCenter` queue for the next seven-day scheduling horizon. That is necessary for local delivery and click routing, but it means the unqualified claim that no event data is persisted would be inaccurate. The queue is macOS-owned rather than a TimeZoner event database.

## Calendar Companion end-to-end acceptance — pending

All rows below are **Pending — not performed in this run**. A deterministic test or the narrow Calendar permission probe is not a manual pass. Record only the installed path, final SHA, macOS version, setup, observed behavior, and Pass/Fail/Pending when a human performs a row; do not record account credentials or calendar content.

| ID | Manual check | Status |
| --- | --- | --- |
| M1 | Discover and identify calendars from two separately configured Google accounts in macOS Calendar. | Pending — not performed in this run. |
| M2 | Verify independent Show and Alerts preferences, including a hidden-but-alert-enabled calendar. | Pending — not performed in this run. |
| M3 | Edit a timed event in Apple Calendar while TimeZoner is open and verify refresh/no stale cancelled or owner-declined content. | Pending — not performed in this run. |
| M4 | Select a timed event across all active city cards, clear it through a normal TimeZoner mutation, and verify an all-day event leaves the reference moment unchanged. | Pending — not performed in this run. |
| M5 | Exercise Today, 3 Days, Week, navigation, Today reset, dense overlap/cross-midnight cases, VoiceOver/keyboard operation, and the return to the normal panel. | Pending — not performed in this run. |
| M6 | Verify right-edge, left-edge, narrow-screen popover wing placement and same-display normal-frame restoration. | Pending — not performed in this run. |
| M7 | Revoke and re-enable Calendar access with visible/selected content; verify clearing, notification cleanup, recovery, and refetch. | Pending — not performed in this run. The probe's denial/recovery result does not certify companion flow. |
| M8 | Exercise reopen/activation, wake, a local-day boundary where practical, and a current-timezone change. | Pending — not performed in this run. |
| M9 | Enable global alerts, grant permission, then deny/revoke in a separate pass; verify the recovery state and default lead times. | Pending — not performed in this run. |
| M10 | Use eligible near-future events to verify future-only 30- and 10-minute banner/sound delivery while hidden, plus muted/ended/all-day exclusions. | Pending — not performed in this run. |
| M11 | Click distinct TimeZoner alerts while running, hidden, and cold-started; verify fresh-event selection or the absolute-time fallback exactly once. | Pending — not performed in this run. |
| M12 | After notification grant, perform a harmless compiled-marker rebuild/reinstall at the same path; then deny/revoke and recover once. | Pending — not performed in this run. |
| M13 | Exercise focus, Escape, global hotkey, activation/deactivation, agenda popover, and both panel surfaces. | Pending — not performed in this run. |

## Notification permission and delivery gate

**NEEDS_CONTEXT — not performed.** The current branch contains notification scheduling, lifecycle reconciliation, a retained delegate, and response routing, but no notification permission, System Settings action, application launch, or packaged-app reinstall was automated. No notification authorization, delivery, click-routing, persistence, denial, or recovery result is claimed here. The Calendar permission observations above do not establish notification authorization behavior.

Human verification still required:

1. Install the built app at its normal path, enable **Calendar alerts**, and grant TimeZoner notification permission when macOS asks.
2. Create a near-future eligible event in real Calendar data, wait for the `timezoner.event.*` alert, and verify foreground banner + sound and clicked-alert routing to the matching event (or the stored timestamp fallback if the event is removed).
3. Quit TimeZoner, make a harmless compiled marker change, rebuild and reinstall at the same path, then reopen and confirm macOS retains notification authorization without a new prompt.
4. Deny or revoke TimeZoner notifications, reopen the app, and verify the global alert toggle resets off while calendar display remains usable and **Open Notification Settings** is offered.
5. Restore the source marker before any commit and record the observed result, installed path, macOS version, and whether the fresh-event or fallback route was exercised.
