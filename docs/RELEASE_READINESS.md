# Release Readiness

**Status as of 2026-07-01:** PR #2 is merged, `v0.3.0` is tagged, the Manual DMG is attached to GitHub Releases, Homebrew can build from the stable release tarball, and the Raycast Store submission PR is open at https://github.com/raycast/extensions/pull/29168. Public Raycast Store distribution still depends on screenshot metadata, Raycast review, and PR merge.

## Ready Now

- Source checkout install: `./install.sh --open`, defaulting to `~/Applications/TimeZoner.app`.
- Homebrew source build: `brew tap nembal/timezoner https://github.com/nembal/Timezoner && brew trust --formula nembal/timezoner/timezoner && brew install timezoner`.
- Homebrew HEAD build: `brew install --HEAD timezoner` for current `main`.
- Homebrew helpers: `timezoner` opens the Cellar app, and `timezoner-install-app [destination]` copies a signed app bundle to `~/Applications` or `/Applications`.
- Manual DMG fallback: `scripts/create-dmg.sh` builds an ad-hoc signed app, includes the SwiftPM resource bundle, and labels the output as a Manual DMG.
- Native URL scheme: `timezoner://open` and `timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF`.
- Raycast source extension: `tz` for Convert Time, `wc` for World Clock, Raycast-local add/remove zone commands, live World Clock refresh, and `Cmd+O` into TimeZoner.app.
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

## Remaining Before Fully Ready

1. Capture real Raycast Store screenshots with Raycast Window Capture and save PNGs into `raycast/metadata/`; recommended shots are documented in `raycast/metadata/README.md`.
2. Copy those PNGs into `extensions/timezoner/metadata/` in the `raycast/extensions` PR branch, commit, and push to https://github.com/raycast/extensions/pull/29168.
3. Wait for Raycast review/merge on https://github.com/raycast/extensions/pull/29168. Address reviewer feedback if they request changes.
4. Run a clean-machine smoke test on a fresh macOS user or VM: Homebrew install, `install.sh`, Manual DMG first launch, Raycast `tz`, Raycast add/remove persistence, and `Cmd+O` deep links.
5. Keep the DMG as a Manual DMG fallback unless the project later chooses to buy an Apple Developer Program account. The primary source-built path does not require it.
