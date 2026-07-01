# Release Readiness

**Status as of 2026-07-01:** PR #2 adds the source-built install path, HEAD-only Homebrew formula, Manual DMG packaging fixes, native deep links, and the Raycast extension. The branch is ready for review and merge, but not yet fully release-distributed.

## Ready Now

- Source checkout install: `./install.sh --open`, defaulting to `~/Applications/TimeZoner.app`.
- Homebrew source build: `brew tap nembal/timezoner https://github.com/nembal/Timezoner && brew install --HEAD timezoner`.
- Homebrew helpers: `timezoner` opens the Cellar app, and `timezoner-install-app [destination]` copies a signed app bundle to `~/Applications` or `/Applications`.
- Manual DMG fallback: `scripts/create-dmg.sh` builds an ad-hoc signed app, includes the SwiftPM resource bundle, and labels the output as a Manual DMG.
- Native URL scheme: `timezoner://open` and `timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF`.
- Raycast source extension: `tz` for Convert Time, `wc` for World Clock, Raycast-local add/remove zone commands, and `Cmd+O` into TimeZoner.app.

## Verified On This Branch

- `scripts/test-install.sh`
- `cd app && swift run TimeZonerTests` with 162 passing tests
- `cd raycast && npm test && npm run lint && npm run build`
- Homebrew formula installed and tested through a temporary local tap with `--HEAD`
- Manual DMG mount/resource/codesign checks
- `open -a <built app> timezoner://set?...` deep-link smoke test

## Remaining Before Fully Ready

1. Merge PR #2 into `main`.
2. Cut the next release tag after merge, then add a stable `url` and `sha256` to `Formula/timezoner.rb`. Until then, the formula must stay HEAD-only.
3. Re-test the stable formula from the release tarball, not only `--HEAD`.
4. Create the release DMG from the merged tag and attach it to GitHub Releases.
5. Submit the Raycast extension to the Raycast Store. The source extension is ready, but public distribution still requires the store PR/review flow.
6. Run a clean-machine smoke test on a fresh macOS user or VM: Homebrew install, `install.sh`, Manual DMG first launch, Raycast `tz`, Raycast add/remove persistence, and `Cmd+O` deep links.
7. Decide whether a paid Apple Developer ID/notarized DMG is worth it. It is not required for the primary source-built path, but it is the only way to make downloaded DMGs feel fully native.
8. Decide release architecture wording. Homebrew builds native on the user's machine; release DMGs should explicitly say whether they are Apple Silicon only or universal.
