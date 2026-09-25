# TimeZoner Calendar Workspace and Transitions

**Status:** Proposed implementation design, 2026-09-25. This document records the user's requested two-panel interaction; the implementation plan is ready for review, not executed.

**Supersedes:** The window ownership, agenda default, calendar toolbar, and calendar-event return behavior in `2026-09-24-calendar-companion-design.md`. Calendar data, range calculations, notifications, privacy, and read-only boundaries continue to apply.

## Goal

Make changing between timezone conversion and calendar browsing feel like two familiar panels exchanging emphasis. Both stay visible. Each has the same chrome, spacing, and typography. A selected meeting remains visible in the calendar while its times appear in the compact TimeZoner rail.

## Current evidence

The screenshot supplied on 2026-09-25 shows the TimeZoner Now/calendar/settings controls at a different inset and vertical position from the Agenda title/date/calendar control. The duplicate calendar glyphs imply the same action even though one toggles agenda visibility and the other changes the workspace.

The code explains the discontinuity:

- `ContentView` replaces its whole root with `CalendarModeView`.
- `CalendarPanelCoordinator.enterCalendarMode()` hides the agenda and immediately resizes the main panel to 760 × 560 without animation.
- Main content uses 20-point horizontal insets; agenda and calendar use 14.
- `DragHandle` changes height from 8 to 20 points depending on menu-bar hugging.
- Calendar has a two-row header and a return control, while agenda has a differently aligned title/date header.
- Selecting a timed grid event invokes the return action, so calendar browsing cannot remain open alongside the cities.

The solution changes panel composition and ownership, rather than compensating with offsets.

## Global constraints

- macOS 14+; use SwiftUI, AppKit, Swift Package Manager, and `@Observable`.
- Zero third-party dependencies, zero direct network clients, no Google OAuth, and no TimeZoner account.
- Calendar reads come only from the local EventKit database; never create, update, delete, accept, or decline events.
- Do not persist event titles, attendee identities, event times, calendar contents, OAuth credentials, or EventKit objects.
- `TimeState.referenceDate` remains the single absolute moment; all reference-moment mutations use `ReferenceMomentController`.
- Calendar ranges and labels use `CalendarStore.localCalendar` and its injected clock, with production `TimeZone.current` behavior.
- Newly unset agenda visibility defaults to on; an explicitly saved off preference stays off. Alerts remain opt-in and unchanged.
- Rendering the agenda or access explanation never requests permission or fetches events without full Calendar access.
- Both workspace panels remain visible; changing focus never hides either panel or dims their text.
- Use the executable `TimeZonerTests` target; automated tests use fakes and never prompt for system permission.
- No event editor, new account system, month view, background agent, new notification behavior, push, release, or external publication.

## Two states, two persistent window owners

| State | Main `FloatingPanel` | Calendar `FloatingPanel` |
| --- | --- | --- |
| TimeZoner | Existing horizontal cards, input, Now, calendar visibility button, settings, map | Agenda with Today/Tomorrow, title/date, expand control |
| Calendar workspace | Compact vertical city rail; Now and expand control; selected-event context | Today / 3 Day / Week grid; navigation, jump to Today, settings |

The calendar window remains the same `NSPanel` in both states. The main window remains the same `NSPanel` in both states. No system fullscreen, third window, or duplicated store is introduced. “Full-size calendar” means the app's normal floating-panel scale, not macOS fullscreen.

Normal agenda placement keeps its existing right/left/popover fallback. Calendar workspace always promotes the calendar into its real panel, even when entry started inside the normal agenda popover. There is exactly one visible calendar presenter.

### Normal TimeZoner

Keep the existing input and city management. The header order remains input → Now → calendar → settings. The calendar control toggles the agenda; it does not enter the workspace. The agenda is visible by default when its saved preference is unset. Existing saved `false` remains respected.

Without Calendar access, the visible agenda shows its explanation or recovery content. The user must activate Enable Calendar Access themselves. The calendar toggle can hide that content without granting or revoking permission. Permission denial does not silently change the user's agenda-visibility choice.

The agenda has a two-line title block within the shared nav slot: `Agenda` and the local date. Its trailing control is `arrow.up.left.and.arrow.down.right`, with label/help `Expand calendar` and hint `Shows the calendar with your time zones beside it.` The calendar icon remains only on the main TimeZoner toolbar.

### Calendar workspace

The main panel becomes a preferred 240-point-wide left rail with vertically stacked read-only city cards. It has no map, search field, add/remove city affordance, drag-reorder handle, calendar visibility button, or settings button. City changes remain available after expanding TimeZoner. The compact cards reuse `TimeFormatter` and the shared reference moment; they do not create another time state.

The rail nav contains only Now and `arrow.up.left.and.arrow.down.right`. The latter expands this panel back into normal TimeZoner, with label/help `Expand TimeZoner` and hint `Restores the full TimeZoner view and compact agenda.` Using the same expansion symbol on the small panel makes the action consistent: expand the panel containing the button. There is no back chevron and no second return control on the large calendar.

A fixed 44-point context slot sits below rail navigation. It shows selected event title and local date/time, or `Current time` with the current timezone when live. Long titles truncate visually to two lines and remain complete in accessibility/help text. Selecting an event does not move the first city card. The card list scrolls vertically and handles zero or many saved cities without changing either workspace frame. Zero cities displays `No saved cities` and `Expand TimeZoner to add a city.`

The calendar targets 760 × 580 points. Its width does not depend on the number of cities. The full top bar replaces TimeZoner's input area with the management controls; settings occupies the same trailing 28-point slot and right inset as in normal TimeZoner.

Normal-width toolbar order:

`[Today | 3 Day | Week]   [‹] [Week 39] [›]   [Today]        [⚙]`

The range selector is 184 points wide, 28 points high, 11-point rounded medium text. Navigation arrows are native chevrons, not text glyphs. The title uses the existing locale-aware range header, and the separate Today button jumps the anchor without changing the selected meeting/reference time. The accessible names distinguish `Day view` from `Jump to today`. Changing range or navigating remains calendar-only state.

At a calendar width below 600 points, replace the segmented selector with a compact native range menu and shorten the navigation title to its essential value (`Week 39`, or the local short date). Keep previous/next, Today, and settings visible in the same single-height nav slot. A quiet date-range/timezone subtitle belongs below navigation, inside the content region; it never pushes the nav baseline.

Clicking a timed event calls `referenceMoment.selectEvent(event, sourceZone: .current)` and stays in the workspace. All-day events retain their existing read-only detail popover and do not change the reference time. Now clears the selected event and resumes live city times without navigating the calendar. The rail expansion control is the only in-app layout-switch action; Escape/global hotkey still hide the pair. Explicit `timezoner://` commands retain their established contract of revealing normal TimeZoner, while notification activation keeps an already-open workspace and focuses its rail context.

## Shared chrome and visual rhythm

All measurements are points. Put them in one shared metric type consumed by the actual views and geometry, rather than copying values into each view.

| Element | Contract |
| --- | --- |
| Outer horizontal inset | 20 |
| Drag strip | Fixed 20 high in every state; hugging changes corner treatment only |
| Space after drag strip | 6 |
| Navigation slot | Fixed 40 high, center-aligned |
| Navigation-to-content gap | 12 |
| Bottom inset | 16 |
| Icon button target | 28 × 28, 14-point medium SF Symbol |
| Now control | 54 × 40, 13-point rounded medium |
| Toolbar text | 12-point rounded medium; range segment text 11 |
| Panel/section title | 14-point rounded semibold |
| Content title/body | 12-point rounded medium / 12-point rounded regular |
| Secondary metadata | 11-point rounded regular |
| Panel corner radius | 12 continuous; square top corners together while menu-bar hugging |
| Inter-panel gap | 10 |
| Card spacing | 10 |

The main and agenda headers share their top edge, nav vertical center, trailing icon target center, and content-start line. The large calendar has the same geometry. Its settings and normal TimeZoner settings share a semantic slot, not a claimed fixed screen coordinate across differently sized panels.

Retain the current adaptive Theme and quiet per-calendar tints. Focus is signaled by a slightly stronger border on the key panel (accent at 0.22 versus normal border), never by fading content. Keep native window shadows for this slice; avoid extra per-frame shadow animation. Both panels use the same background and clipping treatment.

## Geometry and restoration

Capture a normal-layout snapshot once on entry: main frame, agenda frame/placement, screen identifier, and city count. Save a value snapshot, not a window reference. Capture before any layout state changes. A repeated request cannot overwrite it with a rail frame.

Preferred workspace is 240 + 10 + 760 = 1,010 points wide and 580 high, top-aligned. Anchor its right edge at the former agenda's right edge when that agenda is a real right-hand panel; otherwise use the former main frame's right edge. Preserve the captured main top edge. Clamp the pair as one unit to the current screen's visible frame. When room permits, the calendar expands leftward from its right edge while the main panel settles into the left rail.

For widths of at least 570 points, retain side-by-side panels: reserve a 200–240 point rail, 10-point gap, and all remaining width up to 760 for calendar. Below 600 calendar points, use the compact toolbar and horizontal grid scrolling; the grid's header, all-day strip, and timed cells share the existing horizontal geometry. Never compress seven day columns independently.

Below 570 visible points, use two persistent, vertically arranged panels as the defined accessibility fallback: a short, scrollable TimeZoner rail above the calendar, with a 10-point gap. Cards remain vertically stacked inside the short rail. This rare fallback prioritizes reachable controls and both surfaces over the normal left/right arrangement. The geometry function clamps both panels, including unusually short visible frames. No automatic change from Week to Today is allowed.

On return, restore the exact saved normal main frame if the screen and city count are unchanged. Restore the normal agenda frame/placement when still valid; otherwise recalculate attachment at its normal 220-point width. If a display disappeared or its visible frame changed, clamp the restored normal frame to the current visible frame. If a deep link added a city during the workspace, recalculate normal width with the existing city-count formula, preserve the saved top edge and center, and clamp; never restore an obsolete width.

Workspace frame movement must not overwrite the persisted normal panel origin. Dragging either workspace panel moves the pair as a unit and keeps its gap/top alignment; the saved normal position remains intact. Dragging while a transition runs is disabled for the 340 ms transition. Screen changes settle immediately to a clamped layout.

## Motion

Use one coordinator-owned timeline. Do not run separate root-replacement animations, implicit city-count animations, normal agenda attachment callbacks, and AppKit frame resizing against each other.

1. Over 60 ms, fade the changing toolbar/content regions. Panel backgrounds, borders, and drag chrome remain opaque.
2. Over 220 ms, move/resize both real panels in the same `NSAnimationContext` using an ease-in-out timing curve with no overshoot. Switch destination content while it is hidden and clipped; prevent SwiftUI intrinsic size from resizing the windows. The common chrome stays at the same top offset.
3. Over 60 ms, reveal the new toolbar/content with at most 4 points of directional travel. Focus the calendar after entry and the main input after return. No text scaling, bounce, or matched-geometry animation across separate window hosts.

Total: 340 ms. Both opaque panel shells remain present throughout. If entry began in the normal popover, dismiss it and reveal the real calendar panel at a bounded start frame before movement. On reverse, restore the normal popover only after the movement completes, if that was the appropriate placement.

Reduce Motion uses immediate final frames and a 100 ms opacity-only crossfade; no travel or spring. Changing the system setting during animation settles the current target and invalidates scheduled callbacks.

Rapid requests coalesce to the most recently requested destination. Each transition has a monotonically increasing token. A stale completion cannot resize, focus, reveal, or reopen a panel. Escape, app deactivation, screen changes, and explicit hide settle/cancel the active animation before applying their existing lifecycle action. A hide during transition cannot be undone by its completion.

## Focus, settings, and permission ownership

The shared `CalendarPresentationState` remains process-lifetime state. A destination does not mean a different TimeState or a new CalendarStore. Add explicit focused-panel and transition state, and keep window mechanics in the coordinator.

Only the large panel owns settings: main in TimeZoner mode, calendar in workspace. Reuse one settings button/popover component with the same SettingsStore, CalendarStore, preferences, and alert lifecycle. `⌘,` from either panel opens the current owner. Close owned popovers before a layout transition so their anchor never disappears underneath them. The pair's existing popover protection remains in effect while any owned popover is open; closing one schedules a focus recheck.

Use the deferred focus-transfer check already present in `CalendarPanelPairController`. Clicking between the two panels or into settings/event details must not hide the pair. Escape and external app focus retain the current hide behavior. `⌘⇧A` focuses the real calendar panel in workspace and the normal agenda presentation in TimeZoner mode. `⌘N` is inactive in the rail; there is no hidden search focus target.

Calendar permission loss discards calendar snapshots and selected event context immediately through the existing store path. It does not collapse the workspace or turn off the visibility preference: the calendar shows recovery in place, the rail resumes its valid time state, and Now/Expand TimeZoner/settings remain usable. An access grant triggers the current presentation interval automatically; it does not require switching modes. No inaccessible/calendar-only toolbar action can cause EventKit reads before full access.

## Verification and delivery

Deterministic tests cover defaults/access, frame computation/restoration, zero/many cities, negative display coordinates, transition tokens/coalescing, reduced motion, owned-popover focus transfers, settings ownership, timed/all-day activation, and notification/deep-link routing.

Native visual verification covers both light/dark appearances; menu-bar-hugged and floating pairs; 1, 2, 4, and 8 cities; short/long event titles; all three calendar ranges; normal agenda right/left/popover entry; repeated switches; Escape during motion; settings in both layouts; permission recovery; and Reduce Motion. Record actual observations and screenshots, not inferred passes. Preserve existing manual Calendar/notification acceptance rows that this change does not exercise.

This is one cohesive UI change. It should be implemented in small reviewed tasks, then built and installed only after the implementation is authorized. The original Calendar Companion verification is not a substitute for visually checking this transition.
