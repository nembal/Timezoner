# My Day Log Design

**Status:** Draft for user review
**Prototype:** `.superpowers/brainstorm/48555-1794524811/content/my-day-prototype-v2.html` (throwaway, clickable, approved for behavior and color direction)

## Why

The user has ADHD. Time slips away, and at the end of a day it is hard to remember where it went. That feeling is often worse than the lost time itself.

My Day is a self-reporting micro diary inside TimeZoner's calendar workspace. The user writes a few words about what they did and marks it **+** (good use of time) or **−** (drift). They can also plan a block in advance ("4–6 sports"), and a plan can fail. At the end of a day they can see clearly whether it was a good day or not.

The goal is to make good days feel like a win and bad days visible without guilt. It is a mirror, not a coach.

## Goals

- Log what you did in a few words, with an optional + or −, in one text field.
- Plan future blocks in the same text field.
- Close plans after they end: kept or skipped.
- See unlogged gaps and fill them in later.
- See a day score and a week of day scores.
- Keep everything in a local file that the user owns.

## Non-goals

- No hourly ping or any notification. The user was unsure that pings help. (A later, optional ping is possible, but it needs its own design.)
- No writes to Apple Calendar or any EventKit calendar. The calendar companion stays read-only.
- No sync service, no account, no network. iCloud is allowed only as "the user puts the folder in iCloud Drive".
- No Raycast integration.
- No charts, streaks, badges, or analytics beyond the day score and week chips.
- No AI or automatic classification of entries.

## Anti-goals

The feature fails, even if it works, if:

- it nags or shames. Drift is shown quietly. A missed plan costs no points.
- log entries look like meetings and mix into the calendar.
- it uses traffic-light green and red.
- it uses colored stripes on the left edge of blocks. (Hard user rule for all UI in this project.)
- logging takes more than a few seconds.

## Where it lives

My Day is a **layer** of the existing calendar workspace (the Today / 3 Day / Week grid on the merged `main`). It is not a separate app and not a separate window.

A two-segment switch, **Calendar | My day**, sits in `CalendarWorkspaceToolbar`.

- **Calendar** (the current behavior): EventKit meetings show as they do today. Log entries are hidden. Open plans show as slate-blue dashed outlines, because a plan is an intention the user wants to see beside meetings.
- **My day**: log entries and plans are in front. Meetings fade to faint outlines (no fill, thin `Theme.border` outline, `textTertiary` title) so the user still sees where the meetings were. Meetings in My day are not clickable.

The switch value persists in `SettingsStore` (the user returns to the layer they used last).

My Day must work when Calendar access is not granted. Today `CalendarModeView` shows the access screen unless `authorizationStatus == .fullAccess`. In My day, the grid renders with no meetings instead, and the access prompt does not block logging. In Calendar layer, the current access behavior stays.

## Look

Approved direction: use TimeZoner's palette, not green and red.

| Element | Look |
|---|---|
| Good entry (+) | Soft terracotta fill (`Theme.accent` at low opacity, about 18–22%), primary text, small round terracotta badge with "+" at top right |
| Drift entry (−) | Neutral faded grey fill, secondary text, small grey badge with "−" |
| Neutral entry (no mark) | Very light grey fill, no badge |
| Open plan, future | Slate-blue (`Theme.hover`, #527FBF) dashed outline on all four sides, transparent fill, title + "plan · 4–6 PM" |
| Open plan, ended | Same, solid outline, with two small chips: "✓ did it" (terracotta tint) and "✗ skipped" (grey tint) |
| Kept plan | Becomes a good entry, small "plan kept" caption |
| Missed plan | Faint dashed outline, strikethrough title, caption "missed · no penalty" |
| Unlogged gap | Faint diagonal hatch, `textTertiary` caption "2–3 PM · what was it?" |
| Meeting in My day | Outline only, faint |

All colors need light and dark variants through `Color(light:dark:)` like the rest of `Theme`.

Conflict to resolve in build: the grid's current-time line and the today-column tint already use `Theme.accent`. In My day, a terracotta good block could read as "now". Builder's call: either the current-time line uses `textPrimary` in My day, or the good-entry fill stays clearly different from the 7% today tint. Check both in light and dark.

Rounded corners match existing event blocks. The existing all-day and event blocks are out of scope for this work; do not restyle them.

## Entering things

A single text field appears under the toolbar only in the My day layer. Placeholder: `what did you do?`. Enter submits and clears the field. A short status line under the field says what happened ("Logged 2–3 PM", "Planned: sports 4–6 PM") or why nothing happened.

This is a new, separate parser (`DayLogParser`). It does not share code paths with the timezone `InputParser`, and the timezone chat field does not accept log entries.

### Grammar

```
[range] text [+|-]
```

- A trailing `+` or `-` (with optional whitespace) sets the mark. No mark means neutral.
- `range` is optional: `9-11`, `9:30-11`, `4pm-6pm`, `16-18`, `4-6pm`, `9am-10:15am`. An en dash also works.
- Hours without am/pm follow the am/pm inference rule under "Meaning" below.
- Empty text after a range becomes `something`.

### Meaning

The target day is the day the input is for. *(Designer's call.)*

- In the Today range, it is the anchored day.
- In 3 Day and Week ranges, it is today by default. Clicking a day column, a day header, or a gap in that day makes that day the target. The field shows the target when it is not today ("for Tue, Nov 10").
- If the user pages to a range that does not contain the target, the target resets to the first visible day.

Rules by target day:

- **No range:** log from the "last stop" to now. The last stop is the latest end time, before now, of any log entry, kept plan, or covering meeting on the target day, or the day start if none exist. If the last stop is not before now, show "Nothing to log yet" and add nothing. On a past or future target day, "no range" is not allowed: show "Add a time, e.g. 3-4 walk".
- **Range that starts at or after now:** create a plan. A +/− mark on a plan is ignored.
- **Range that starts less than 15 minutes before now:** also create a plan, so "4-6 sports" typed at 4:05 is still a plan. *(Designer's call.)*
- **Range that starts 15 minutes or more before now:** create a log entry. Clip the end to now.
- On a future target day, every range is a plan. Gaps and Close the day are hidden for future days.

**Covering meetings** *(designer's call)*: only timed events count. They must have busy availability, and the current account must not have declined them. All-day, free, and declined events never cover time or set the last stop. Tentative events count.

**Am/pm inference** *(designer's call)*: when am/pm is missing on one or both ends, choose the reading that gives the shortest positive interval within one day, preferring the morning for 8–11 and the afternoon for 1–7 when both are equal. So "11-1pm" is 11 AM–1 PM, and "4-6" is 4–6 PM.

Overlaps are allowed. Overlapping log entries use the same lane logic as overlapping meetings.

## Plans

Plan states: `open`, `kept`, `missed`.

- After the plan's end time, an open plan shows the two chips. Tapping "✓ did it" makes it `kept` and gives it a + mark. Tapping "✗ skipped" makes it `missed`.
- Open plans that have ended also appear in **Close the day**.
- There are no reminders. An open plan can stay open forever. It counts as nothing until closed.

**Mark and state together** *(designer's call)*: plans store both `state` and `mark` in the file. Marking a plan kept sets its mark to `plus`. After that the user can change the mark in the edit popover, and the score always uses the mark, not the state. The popover also has a state picker (open / kept / missed), so a missed plan can be reopened or kept. Moving an open plan's times does not change its state.

## Gaps

A gap is past time on the target day, from the day start to now (or to the end of a past day), that no log entry, kept plan, or meeting covers, and that is 30 minutes or longer. Clicking a gap fills the text field with its range (`2pm-3pm `) and focuses the field.

Day start and day end are settings, default 9:00 and 22:00. Gaps exist only between day start and day end, so late-night time never shows as a gap.

## Late nights

*(User decision.)* The log day rolls over at **4 AM**, not at midnight.

- Between midnight and 4 AM, "today" for logging is still the previous date. At 12:30 AM, "gaming −" logs into the previous day's file, from its last stop to 12:30 AM.
- A range can cross midnight. "11-1 gaming −", typed at 1:30 AM, is 11 PM to 1 AM and belongs to the previous date. Any range that starts before 4 AM is read as the end of the previous log day, unless the user is on a target day where that time is still in the future.
- An entry belongs to the file of the log day it starts in. The grid draws it with the existing cross-midnight clipping: one piece at the bottom of the first column and one at the top of the next.
- The 4 AM rollover affects only the log. The calendar's "Today" button and today column still follow the normal midnight boundary.

## Travel

*(User decision.)* Each day shows at its own local times.

- Every day file stores the `timeZone` where it was logged. Entries are drawn at their wall-clock times in that time zone, in that date's column. "9 AM emails" logged in San Francisco still shows at 9 AM when viewed in Bangkok.
- "Now", the last stop, and plan state use the current Mac time zone, and only affect the current log day.
- Meetings keep the calendar's current behavior (current Mac time zone). On a day logged in another time zone, meetings and log entries can therefore look out of line. This is accepted. My day draws meetings only as faint outlines anyway.
- If the time zone changes in the middle of a log day, the day file keeps its first `timeZone`, and new entries are drawn in it.

## Score

- Day score = the count of entries marked `plus`, minus the count marked `minus`. This includes plans by their mark. Open and missed plans have no mark by default and count 0. Neutral entries count 0.
- The side summary shows the score, a bar of good hours vs. drift hours, and "plans kept X/Y", where Y is every plan on that day, including open ones.
- In My day, each day header in the 3 Day and Week ranges shows a small score chip (terracotta tint when the score is ≥ 0, grey when it is below 0).
- The summary also has a "This week" chip row (Mon to Sun of the locale week that contains the target day) in every range, including Today. `DayLogStore` therefore always loads that whole week, plus any other visible days. *(Designer's call.)*

The summary sits in a compact strip under the text field, or in a side column when the panel is wide. Builder's call, as long as the grid keeps its current width rules.

## Close the day

A **Close the day** button in the My day layer opens a small popover. It lists open plans that ended (with ✓ / ✗) and gaps (with "fill"). When both lists are empty, it shows one plain line based on the score:

- score > 0: "Good day. You did real things today."
- score = 0: "Even day. Tomorrow is a fresh page."
- score < 0: "Rough day, and you still wrote it down. That counts."

Closing the day does not lock the day. The user can still edit it.

## Editing

Clicking a log entry or a plan opens a small popover:

- edit the text,
- set the mark: +, neutral, or −,
- change the start and end times (simple steppers or time pickers),
- delete.

There is no undo stack. Delete asks nothing; the popover shows "Deleted · Undo" for a few seconds instead of a confirm dialog.

## Storage

- One JSON file per day: `<folder>/YYYY-MM-DD.json`, named by the local calendar date.
- Default folder: `~/Library/Application Support/TimeZoner/DayLog/`.
- Settings has a "Day log folder" picker, so the user can choose a folder in iCloud Drive. Changing the folder does not move old files; it only changes where the app reads and writes.
- Write atomically (temp file plus rename). Reload a day file when the app opens the My day layer or when the file changes on disk (iCloud may update it).

File shape:

```json
{
  "version": 1,
  "date": "2026-11-13",
  "timeZone": "America/Los_Angeles",
  "entries": [
    { "id": "UUID", "kind": "log",  "start": "2026-11-13T09:00:00-08:00", "end": "2026-11-13T10:00:00-08:00", "text": "emails", "mark": "minus" },
    { "id": "UUID", "kind": "plan", "start": "2026-11-13T16:00:00-08:00", "end": "2026-11-13T18:00:00-08:00", "text": "sports", "state": "open" }
  ]
}
```

- `mark`: `plus`, `minus`, or `none`, on every entry including plans (omitted means `none`). `state` (plans only): `open`, `kept`, `missed`.
- Times are ISO 8601 with offset, so a day logged in Bangkok still reads correctly later in San Francisco. The file belongs to the local date when the entry was made.
- Unknown fields are kept on rewrite where practical; a file with a higher `version` is shown read-only.

TimeZoner persists nothing else about the log. Meeting data is never written to these files.

## Code shape

Follow the existing pattern: pure, testable models in `TimeZonerLib`, thin SwiftUI views.

- `DayLogEntry`, `DayLogDay` — value types matching the file.
- `DayLogParser` — text to a parse result, given "now", the target day, the day start, and the existing entries and meetings. Pure.
- `DayLogScoring` — score, hours, plans kept, gaps. Pure.
- `DayLogFileStore` — reads and writes day files behind a protocol, so tests use an in-memory fake.
- `DayLogStore` — `@MainActor @Observable`, owns the loaded days for the visible range, applies parser results, and saves.
- The time grid draws log entries and plans as a second set of blocks. Reuse `CalendarGridMetrics` for vertical placement and overlap lanes. Builder decides whether that is a new segment type or a parallel draw pass.
- The layer switch value lives in `CalendarPresentationState` (session) and `SettingsStore` (persisted).

## Testing

Automated, in the existing `TimeZonerTests` runner:

- Parser: every range form, am/pm inference, trailing marks, empty text, the "no range" rule, future → plan, past → log with clipped end, past-day rules.
- Scoring: counts, hours, kept and missed plans, neutral entries.
- Gaps: meetings, entries, and kept plans cover time; the 30-minute minimum; day start and end; past days.
- Plan state changes.
- File store: round-trip, atomic write, unknown `version`, missing folder created, timezone offsets.
- Layer switch persistence, and My day working with no calendar access.

Manual:

1. Log a few entries with and without ranges, and see them on the grid.
2. Plan a block, move past its end, and close it both ways.
3. Fill a gap by clicking it.
4. Use Close the day on a full day and on an empty day.
5. Switch layers and confirm meetings fade, and log entries hide in Calendar.
6. Check light and dark mode, with no left-edge stripes anywhere.
7. Point the folder at iCloud Drive, edit on disk, and confirm the app reloads.

## Left to the builder

- The exact SwiftUI layout of the text field, summary, and Close the day button within current panel width rules.
- Exact opacities and the current-time line conflict noted above, within the look table.
- Whether log blocks are a new segment type or a parallel draw pass.
- The file-watching mechanism.
