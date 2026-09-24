# Calendar permission spike — 2026-09-24

## Scope and privacy boundary

This packaged probe verifies only macOS Calendar authorization behavior for the source-built, ad-hoc-signed `TimeZoner.app`. It reads calendar descriptors and a seven-day event count only after full access has been granted. It has no calendar write operation, network request, account sign-in, or persistence of event or attendee data.

The normal application launch does not construct the probe or request Calendar access. The probe is selected only with `--calendar-permission-spike`.

## Non-interactive verification

- `cd app && swift run TimeZonerTests`: passed, `174 passed, 0 failed out of 174 tests`; no Calendar prompt appeared.
- `bash scripts/test-install.sh`: passed; it built, ad-hoc signed, installed to a temporary destination, verified the package resource, and verified the signature.
- `./install.sh`: passed; it built, ad-hoc signed, and restored marker `calendar-permission-probe` at `/Users/team/Applications/TimeZoner.app` without launching it.
- Usage description: `NSCalendarsFullAccessUsageDescription` is set to `TimeZoner reads your calendars to show upcoming events across your saved time zones.`
- Probe marker: `calendar-permission-probe`.

## Human authorization results

Calendar permission changes were performed by a human. Automation did not perform any authorization, revocation, recovery, launch, or UI interaction.

- Initial Calendar grant succeeded. The exact calendar and event count values were not supplied.
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
| Initial real calendar/event count | Not supplied; no counts are claimed. |
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

**DONE_WITH_CONCERNS.** The human observations establish successful grant, changed-rebuild persistence without a new prompt, denial, and recovery. The exact real calendar/event count values were not captured, so this document does not claim them. The privacy-settings visibility follow-up is package-tested but awaits an optional visual confirmation on a future manual use.
