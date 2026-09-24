# Release Readiness

**Status as of 2026-07-02:** PR #2 is merged, `v0.3.0` is tagged, the Manual DMG is attached to GitHub Releases, Homebrew can build from the stable release tarball, and the Raycast Store submission PR is open at https://github.com/raycast/extensions/pull/29168. Public Raycast Store distribution still depends on screenshot metadata, Raycast review, and PR merge.

## Ready Now

- Source checkout install: `./install.sh --open`, defaulting to `~/Applications/TimeZoner.app`.
- Homebrew source build: `brew tap nembal/timezoner https://github.com/nembal/Timezoner && brew trust --formula nembal/timezoner/timezoner && brew install timezoner`.
- Homebrew HEAD build: `brew install --HEAD timezoner` for current `main`.
- Homebrew helpers: `timezoner` opens the Cellar app, and `timezoner-install-app [destination]` copies a signed app bundle to `~/Applications` or `/Applications`.
- Manual DMG fallback: `scripts/create-dmg.sh` builds an ad-hoc signed app, includes the SwiftPM resource bundle, and labels the output as a Manual DMG.
- Native URL scheme: `timezoner://open` and `timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF`.
- Raycast source extension: one `tz` TimeZoner command for live world clock, same-screen card time editing through the search bar, one-click edit retargeting between cards, static map preview under the timezone cards, time conversion, Raycast-local add/edit/remove zone commands, and `Cmd+O` into TimeZoner.app.
- Raycast Store submission: https://github.com/raycast/extensions/pull/29168, with initial Greptile review feedback addressed except for real screenshot PNGs.

## Verified On This Branch

- `scripts/test-install.sh`
- `cd app && swift run TimeZonerTests` with 162 passing tests
- `cd raycast && npm test && npm run lint && npm run build`
- Homebrew formula installed and tested through a temporary local tap with `--HEAD`.
- Homebrew stable formula installed and tested from the real GitHub tap with Homebrew tap trust enabled.
- Raycast extension validated in the `raycast/extensions` fork with `npx tsc -p tsconfig.json --noEmit`, `npm test`, `npm run lint`, and `npm run build`; store PR opened and review-fix commit pushed.
- Manual DMG mount/resource/codesign checks.
- `v0.3.0` release tarball SHA256: `59c129efb6900881f55d6187f372cac6f154321be2de474b6427732febfe357c`.
- `open -a <built app> timezoner://set?...` deep-link smoke test

## Calendar Companion — current branch, not released

Calendar Companion is implemented on the current branch but is not part of the dated `v0.3.0` release described above. It reads the accounts already configured in macOS Calendar through EventKit; it has no Google sign-in, Google Calendar API client, TimeZoner account, or direct network calendar client. macOS requests Full Access to read events, while TimeZoner's Calendar implementation remains read-only: it never creates, changes, deletes, accepts, or declines an event.

The agenda and grid keep event data in memory for presentation. TimeZoner persists normal app settings plus per-calendar identifier-keyed Show/Alerts preferences and alert lead-time settings, not an app-owned event or attendee database. Attendee labels are displayed locally from EventKit values; where a display name is unavailable, the current mapper may use an address-derived label. Optional alerts are a deliberate exception to the in-memory presentation boundary: when enabled, macOS's local notification queue retains the event title, occurrence identifier, and start timestamp for eligible occurrences in the next seven days. The queue supports delivery and response routing; it is not a TimeZoner-owned database.

### Current-branch automated and package evidence

Completed on 2026-09-24 against final code SHA `51c96bb` immediately before this evidence-refresh documentation-only change:

- `cd app && swift run TimeZonerTests` — **548 passed, 0 failed**.
- `./scripts/build.sh` — passed and produced an ad-hoc-signed `app/TimeZoner.app`.
- `codesign --verify --deep --strict app/TimeZoner.app` — passed.
- The packaged `NSCalendarsFullAccessUsageDescription` is exactly: `TimeZoner reads your calendars to show upcoming events across your saved time zones.`
- `bash scripts/test-install.sh` — passed; it built, signed, installed to a temporary destination, and checked the resource/signature layout.
- Source audits found `EKEventStore` only in `EventKitCalendarProvider`; UserNotifications are limited to the notification adapter, retained delegate, and intentional AppDelegate installation. The targeted event/attendee-to-`UserDefaults` scan had no match. A review of persistence/network references found normal `UserDefaults` stores only and no direct network calendar client.

These are deterministic/code and package checks. They do not prove macOS permission UX, real account data, panel behavior, notification delivery, or notification response routing.

### Manual acceptance and release blockers

- The packaged Calendar-permission probe has a narrow human observation at `/Users/team/Applications/TimeZoner.app`: grant, a real fetch with uncaptured counts, one same-path changed ad-hoc rebuild that retained Full Access, revocation, and recovery on macOS 26.6.2 (25G83). It is not a general upgrade, release, or distribution-identity guarantee.
- **Notification authorization and delivery remain NEEDS_CONTEXT.** No human grant/denial/recovery, real banner/sound delivery, notification click, or changed-rebuild persistence result is recorded. Calendar permission evidence does not establish notification behavior.
- The full companion acceptance matrix is pending: two macOS-configured Google accounts, independent Show/Alerts behavior, Apple Calendar change refresh, event-to-timezone selection, Today/3 Days/Week navigation, wing placement and focus/Escape, Calendar revocation/recovery, wake/timezone/reopen refresh, and notification behavior while running, hidden, and cold-started. See [the verification record](verification/calendar-permission-spike-2026-09-24.md) for every pending row.
- Calendar Companion has no background agent. Its code reconciles the next seven days while TimeZoner is running or on a later launch; calendar changes made while it is quit are not incorporated until then, and it cannot roll the horizon forward while it remains quit. This lifecycle behavior still needs the native acceptance observations above.
- A release, tag, Homebrew update, deployment, or publication for Calendar Companion is outside this branch's scope and requires separate authorization.

## Remaining Before Fully Ready

1. Capture real Raycast Store screenshots with Raycast Window Capture and save PNGs into `raycast/metadata/`; recommended shots are documented in `raycast/metadata/README.md`.
2. Copy those PNGs and `raycast/ATTRIBUTION.md` into `extensions/timezoner/metadata/` and `extensions/timezoner/` in the `raycast/extensions` PR branch, commit, and push to https://github.com/raycast/extensions/pull/29168.
3. Wait for Raycast review/merge on https://github.com/raycast/extensions/pull/29168. Address reviewer feedback if they request changes.
4. Run a clean-machine smoke test on a fresh macOS user or VM: Homebrew install, `install.sh`, Manual DMG first launch, Raycast `tz`, same-screen card time editing, one-click card switching while editing, map-under-cards preview, `3pm in SF`, Raycast add/edit/remove persistence, and `Cmd+O` deep links.
5. Keep the DMG as a Manual DMG fallback unless the project later chooses to buy an Apple Developer Program account. The primary source-built path does not require it.
