# Calendar permission spike — 2026-09-24

## Scope and privacy boundary

This packaged probe verifies only macOS Calendar authorization behavior for the source-built, ad-hoc-signed `TimeZoner.app`. It reads calendar descriptors and a seven-day event count only after full access has been granted. It has no calendar write operation, network request, account sign-in, or persistence of event or attendee data.

The normal application launch does not construct the probe or request Calendar access. The probe is selected only with `--calendar-permission-spike`.

## Non-interactive verification

- `cd app && swift run TimeZonerTests`: passed, `173 passed, 0 failed out of 173 tests`; no Calendar prompt appeared.
- `bash scripts/test-install.sh`: passed; it built, ad-hoc signed, installed to a temporary destination, verified the package resource, and verified the signature.
- `./install.sh`: passed; it built, ad-hoc signed, and reinstalled marker `calendar-probe-b` at `/Users/team/Applications/TimeZoner.app`.
- Usage description: `NSCalendarsFullAccessUsageDescription` is set to `TimeZoner reads your calendars to show upcoming events across your saved time zones.`
- Probe marker: `calendar-probe-b`.

## Human authorization gate

Calendar permission changes are security-sensitive and must be performed by a human in the installed app and System Settings. A human reported that the initial Calendar grant succeeded, but did not supply the displayed calendar or event counts. Automation did not perform any authorization, revocation, recovery, launch, or UI interaction.

The initial probe exposed a usability defect: its text and controls floated over the transparent `FloatingPanel` without a readable surface. The probe now paints an opaque, rounded `Theme.background` with the existing border and shadow, and the harmless compiled marker change to `calendar-probe-b` was rebuilt and reinstalled at the same path.

Do not proceed to Calendar Companion Core until every remaining observation below is recorded and the changed-rebuild behavior is judged stable for ordinary upgrades.

1. Launch the current installed `calendar-probe-b` build:

   ```sh
   open "$HOME/Applications/TimeZoner.app" --args --calendar-permission-spike
   ```

2. Record its status and the calendar/event counts. If access persists, the status should be `Full access` and a real count should appear; if it re-prompts, denies, or needs recovery, record that exact result. Do not create or modify calendar data for this check.
3. Record the exact installed path, `sw_vers`, and `codesign -dr - "$HOME/Applications/TimeZoner.app"` output.
4. Revoke TimeZoner Calendar access in System Settings, relaunch the probe, confirm the unavailable state, click `Open Calendar Privacy Settings`, grant access once more, and record whether the probe fetches real counts again.

## Observation record

| Check | Observation |
| --- | --- |
| Initial status | Human reported Calendar grant succeeded; exact probe status text was not supplied. |
| Initial real calendar/event count | Not supplied by human. |
| Initial probe surface | Defect observed: content was drawn over a transparent/no-background panel. Fixed in the `calendar-probe-b` rebuild with an opaque rounded surface. |
| Installed path | `/Users/team/Applications/TimeZoner.app` |
| macOS version | macOS 26.6.2 (build 25G83) |
| Designated requirement | `designated => cdhash H"db41145ae6ba8dc5bb260e050b422533e55f8af6"` for current marker `calendar-probe-b` build. |
| Changed-rebuild result | Rebuild/reinstall complete at the same path; not launched by automation, so persistence/re-prompt/denial/recovery is not yet observed. |
| Denial and recovery result | Not yet performed — human interaction required. |

## Gate decision

**Pending human security-sensitive observations.** Do not claim Calendar permission persistence, and do not begin the Calendar Companion Core implementation, until the changed-rebuild and denial/recovery results above are recorded and stable.
