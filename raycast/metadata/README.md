# TimeZoner Store Screenshots

Raycast Store review requires screenshots in this `metadata/` folder.

Use Raycast Window Capture:

1. Open Raycast Preferences -> Advanced and set a Window Capture hotkey.
2. In this directory, run `npm run dev`.
3. Open each command in Raycast development mode.
4. Press the Window Capture hotkey and tick `Save to Metadata`.

Capture at least these PNGs:

- `timezoner-convert-time.png`: Convert Time with query `3pm SF`.
- `timezoner-cross-zone.png`: Convert Time with query `1130am BKK in SF`.
- `timezoner-world-clock.png`: World Clock showing the saved zone list.

Raycast's screenshot spec is 2000 x 1250 PNG, landscape, 16:10. Use the same desktop background for all screenshots and avoid showing other apps.

After capture, keep the PNGs in this folder and copy them to `extensions/timezoner/metadata/` in the `raycast/extensions` Store PR branch before pushing the final Store update.
