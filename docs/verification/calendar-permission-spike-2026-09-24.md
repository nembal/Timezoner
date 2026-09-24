# Calendar permission spike — 2026-09-24

## Scope and privacy boundary

This packaged probe verifies only macOS Calendar authorization behavior for the source-built, ad-hoc-signed `TimeZoner.app`. It reads calendar descriptors and a seven-day event count only after full access has been granted. It has no calendar write operation, network request, account sign-in, or persistence of event or attendee data.

The normal application launch does not construct the probe or request Calendar access. The probe is selected only with `--calendar-permission-spike`.

## Non-interactive verification

- `cd app && swift run TimeZonerTests`: passed, `171 passed, 0 failed out of 171 tests`; no Calendar prompt appeared.
- `bash scripts/test-install.sh`: passed; it built, ad-hoc signed, installed to a temporary destination, verified the package resource, and verified the signature.
- `./install.sh`: passed; it built, ad-hoc signed, and installed `/Users/team/Applications/TimeZoner.app`.
- Usage description: `NSCalendarsFullAccessUsageDescription` is set to `TimeZoner reads your calendars to show upcoming events across your saved time zones.`
- Probe marker: `calendar-permission-probe`.

## Human authorization gate — not performed by automation

Calendar permission changes are security-sensitive and must be performed by a human in the installed app and System Settings. Do not proceed to Calendar Companion Core until every observation below is recorded and the changed-rebuild behavior is judged stable for ordinary upgrades.

1. For the first permission observation, temporarily change the compiled probe marker in `app/Sources/App/CalendarPermissionProbeView.swift` from `calendar-permission-probe` to `calendar-probe-a`, rebuild and reinstall at the same path, then launch the installed probe:

   ```sh
   open --args "$HOME/Applications/TimeZoner.app" --calendar-permission-spike
   ```

2. Record the initial status. If it is `Not determined`, click `Enable Calendar`, grant access in the system prompt, and record the resulting calendar and seven-day event counts. Do not create or modify calendar data for this check.
3. Record the exact installed path, `sw_vers`, and `codesign -dr - "$HOME/Applications/TimeZoner.app"` output.
4. Quit the app. Change the compiled probe marker from `calendar-probe-a` to `calendar-probe-b`, rebuild and reinstall at the same path. Record whether Calendar access persists, re-prompts, denies, or requires System Settings recovery. Restore the marker to `calendar-permission-probe` before committing.
5. Revoke TimeZoner Calendar access in System Settings, relaunch the probe, confirm the unavailable state, click `Open Calendar Privacy Settings`, grant access once more, and record whether the probe fetches real counts again.

## Observation record

| Check | Observation |
| --- | --- |
| Initial status | Not yet performed — human interaction required. |
| Initial real calendar/event count | Not yet performed — human interaction required. |
| Installed path | `/Users/team/Applications/TimeZoner.app` |
| macOS version | macOS 26.6.2 (build 25G83) |
| Designated requirement | `designated => cdhash H"88c87f0b8a85278e72ddaf71b42bb4e95e491d7f"` |
| Changed-rebuild result | Not yet performed — human interaction required. |
| Denial and recovery result | Not yet performed — human interaction required. |

## Gate decision

**Pending human security-sensitive observations.** Do not claim Calendar permission persistence, and do not begin the Calendar Companion Core implementation, until the changed-rebuild and denial/recovery results above are recorded and stable.
