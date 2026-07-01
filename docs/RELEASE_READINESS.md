# Release Readiness

**Status as of 2026-07-01:** PR #2 is merged, `v0.3.0` is tagged, the Manual DMG is attached to GitHub Releases, and Homebrew can build from the stable release tarball. The Raycast extension is source-installable, but public Raycast Store distribution still requires the store submission/review flow.

## Ready Now

- Source checkout install: `./install.sh --open`, defaulting to `~/Applications/TimeZoner.app`.
- Homebrew source build: `brew tap nembal/timezoner https://github.com/nembal/Timezoner && brew trust --formula nembal/timezoner/timezoner && brew install timezoner`.
- Homebrew HEAD build: `brew install --HEAD timezoner` for current `main`.
- Homebrew helpers: `timezoner` opens the Cellar app, and `timezoner-install-app [destination]` copies a signed app bundle to `~/Applications` or `/Applications`.
- Manual DMG fallback: `scripts/create-dmg.sh` builds an ad-hoc signed app, includes the SwiftPM resource bundle, and labels the output as a Manual DMG.
- Native URL scheme: `timezoner://open` and `timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF`.
- Raycast source extension: `tz` for Convert Time, `wc` for World Clock, Raycast-local add/remove zone commands, and `Cmd+O` into TimeZoner.app.

## Verified On This Branch

- `scripts/test-install.sh`
- `cd app && swift run TimeZonerTests` with 162 passing tests
- `cd raycast && npm test && npm run lint && npm run build`
- Homebrew formula installed and tested through a temporary local tap with `--HEAD`.
- Homebrew stable formula installed and tested from the real GitHub tap with Homebrew tap trust enabled.
- Manual DMG mount/resource/codesign checks.
- `v0.3.0` release tarball SHA256: `59c129efb6900881f55d6187f372cac6f154321be2de474b6427732febfe357c`.
- `open -a <built app> timezoner://set?...` deep-link smoke test

## Remaining Before Fully Ready

1. Submit the Raycast extension to the Raycast Store. The source extension is ready, but public distribution still requires the store PR/review flow.
2. Run a clean-machine smoke test on a fresh macOS user or VM: Homebrew install, `install.sh`, Manual DMG first launch, Raycast `tz`, Raycast add/remove persistence, and `Cmd+O` deep links.
3. Keep the DMG as a Manual DMG fallback unless the project later chooses to buy an Apple Developer Program account. The primary source-built path does not require it.
