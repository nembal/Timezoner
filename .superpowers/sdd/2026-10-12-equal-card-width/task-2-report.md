# Task 2 verification report — 2026-10-12

## Result

The four- and five-city hosted renders show equal 200-point cards with readable Bangkok, SF, New York, and Budapest labels and GMT offsets. Adding Tokyo grows the preferred panel width from 948 to 1184 points without shrinking any card. The ellipsis now occupies its own row at the fixed horizontal width. On a 1000-point display, the main panel caps at 1000 points and its card row scrolls horizontally; a rendered scrolled view exposes Tokyo. Agenda placement is recalculated after resizing and uses the opposite side or popover as space allows.

## Commands and raw results

- `cd app && bash fix-spm.sh`: exit 0; wrapper installed at `/tmp/spm-fix/swiftc-wrapper.sh`.
- `cd app && SWIFT_EXEC=/tmp/spm-fix/swiftc-wrapper.sh swift run TimeZonerTests > /tmp/timezoner-task2-tests-final.log 2>&1`: exit 0. Raw tail:
  ```text
  Running CalendarStoreTests...
  Running CalendarNotificationTests...

  Results: 936 passed, 0 failed out of 936 tests
  All tests passed!
  ```
- `./build.sh > /tmp/timezoner-task2-build-final.log 2>&1`: exit 0. Raw tail:
  ```text
  [14 / 14] TimeZoner-product
  [15 / 16] TimeZoner-product
  Build complete! (16.02 sec)
  TimeZoner.app: replacing existing signature
  Built TimeZoner.app (signed ad-hoc)
  ```
- `git diff --check`: exit 0, no output.

The pre-fix overflow test run at `/tmp/timezoner-task2-overflow-red.log` failed four expected assertions: five-city left-edge containment, clamped origin, recalculated left agenda frame, and narrow-screen width. The final run above passed them.

## Visual evidence

A temporary `NSHostingView` harness in the test executable rendered the actual `ZoneCardRow` from this checkout with isolated in-memory zones and no changes to user defaults. The temporary harness and runner hook were removed after capture. I inspected these PNGs at original resolution:

- `/tmp/timezoner-card-evidence/cards-4.png` — four full names and GMT offsets; equal 400-pixel card widths at 2× scale; separate ellipsis row.
- `/tmp/timezoner-card-evidence/cards-5.png` — same four card widths after Tokyo is added; fifth card is also 400 pixels wide.
- `/tmp/timezoner-card-evidence/cards-5-narrow.png` — the 1000-point viewport clips the fifth fixed-width card.
- `/tmp/timezoner-card-evidence/cards-5-narrow-scrolled.png` — scrolling the hosted `NSScrollView` by 184 points exposes Tokyo without resizing cards.

The render log is `/tmp/timezoner-task2-render.log`. The final standalone app was built from this checkout at `app/TimeZoner.app`. CUA's attempt to launch that exact bundle path timed out, so live clicks, drag gestures, map toggles, and calendar transitions were not visually exercised in the running app. The executable tests cover edit and ordering actions, zero/one-city minimum sizing, map panel sizing, agenda attachment, and return from calendar after adding a city. Those are model and view-render checks, not a claim of live end-to-end gesture coverage.

## Self-review

- Only the normal main panel's resize path was clamped. Its preferred width remains 948/1184 on displays that fit; narrow displays cap the panel while fixed-width cards remain available by horizontal scrolling. The top edge remains fixed during resizing.
- Right, left, and popover agenda cases run through the real pair controller with controlled panel surfaces. The return case runs through workspace restoration and the pair controller after a city-count change.
- The vertical card collection retains flexible width. Its existing measured-width fallback for header layout was not changed; no live vertical-rail visual interaction was verified.
- Native UI automation remains a verification gap. No install, user preference mutation, push, merge, or publication was performed.
