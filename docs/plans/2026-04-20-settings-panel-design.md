# Settings Panel — Design

**Date:** 2026-04-20
**Status:** Implemented with scope adjustments. Appearance, launch at login, global hotkey, input-format help, and Quit shipped in the settings popover. The frosted-glass toggle did not ship.

## Goals

Original goal: add a user-facing Settings popover to TimeZoner covering:

1. **Appearance override** — System / Light / Dark (app-wide)
2. **Launch at login**
3. **Frosted glass toggle** for the panel background (not shipped)
4. **Global hotkey** to show/hide the panel (default ⌘⌥T)
5. Migrate existing input-format help content into Settings

## Current implementation

The shipped `SettingsStore` has `appearance`, `launchAtLogin`, and `hotkey`. There is no `settings.frostedGlass` key in the current app, and the settings popover does not show a frosted-glass toggle.

## Non-goals

- Default-cities picker, sync, accounts, themes beyond light/dark — explicitly out of scope.
- A standard macOS Preferences window or status-bar menu — deferred.

## UX

Replace the current `?` button in the panel header with a ⚙ gear. Clicking it opens a popover anchored to the gear. All changes apply immediately — no Save/Close buttons.

```
┌─ Settings ────────────────────────────┐
│  Appearance    (●) System             │
│                ( ) Light              │
│                ( ) Dark               │
│  ───────────────────────────────────  │
│  Global hotkey   [ ⌘⌥T      ] [Clear] │
│  [✓] Launch at login                  │
│  [✓] Frosted glass background         │
│  ───────────────────────────────────  │
│  Input formats                        │
│    11:30am SF      3pm bangkok        │
│    noon NYC        midnight CET       │
│    +Tokyo          -NYC               │
│  ───────────────────────────────────  │
│  TimeZoner v0.x           [Quit]      │
└───────────────────────────────────────┘
```

Popover dismisses on outside click. Width ~320pt, height fits content.

## Architecture

### New files

```
app/Sources/
  Stores/
    SettingsStore.swift           # @Observable, UserDefaults-backed
  Utilities/
    HotkeyManager.swift           # Carbon RegisterEventHotKey wrapper
    LaunchAtLogin.swift           # SMAppService helper
  Views/
    SettingsPopover.swift         # Popover content
    HotkeyRecorderField.swift     # Keystroke-capturing text field
```

### Removed

- `app/Sources/Views/HelpPopover.swift` — content migrates into `SettingsPopover`.

### Edited

- `ContentView.swift` — replace `?` button with ⚙, re-target the popover.
- `TimeZonerApp.swift` / `AppDelegate` — load settings, apply appearance, register hotkey, reconcile login-item state on launch.
- `FloatingPanel.swift` (and/or `Theme.swift`) — observe `frostedGlass`, toggle between `NSVisualEffectView` and a solid background.

## Data model

```swift
@Observable final class SettingsStore {
    enum AppearancePref: String, Codable { case system, light, dark }

    struct Shortcut: Codable, Equatable {
        var keyCode: UInt32      // Carbon virtual key
        var modifiers: UInt32    // Carbon modifier mask
        var display: String      // "⌘⌥T" for the recorder field
    }

    var appearance: AppearancePref  { didSet { applyAppearance(); persist() } }
    var launchAtLogin: Bool         { didSet { syncLoginItem();  persist() } }
    var frostedGlass: Bool          { didSet { broadcast();      persist() } }
    var hotkey: Shortcut?           { didSet { rebindHotkey();   persist() } }
}
```

### UserDefaults keys

- `settings.appearance` — String
- `settings.launchAtLogin` — Bool
- `settings.frostedGlass` — Bool
- `settings.hotkey` — JSON-encoded `Shortcut`

### First-launch defaults

| Setting        | Default                  |
| -------------- | ------------------------ |
| appearance     | `.system`                |
| launchAtLogin  | `false`                  |
| frostedGlass   | `true` (current look)    |
| hotkey         | `⌘⌥T`                   |

## Startup sequence

In `applicationWillFinishLaunching` (so the panel never paints wrong):

1. Load `SettingsStore` from UserDefaults.
2. Apply `NSApp.appearance` from `appearance`.

Then in `applicationDidFinishLaunching`:

3. Reconcile login item — if `launchAtLogin == true` but `SMAppService.mainApp.status != .enabled`, re-register.
4. Register hotkey via `HotkeyManager.shared.rebind(settings.hotkey)`.
5. Build the panel (reads `frostedGlass` during construction).

## Key design decisions

- **App-wide appearance** — `NSApp.appearance` covers panel, popovers, future windows. One line, one source of truth.
- **Carbon for hotkey** — `RegisterEventHotKey` gives true system-wide interception; keeps zero-dep rule; ~80 lines of wrapper.
- **Default ⌘⌥T, not ⌘⇧T** — ⌘⇧T is "reopen closed tab" in every browser; a global hotkey intercepts before the browser sees it, silently breaking muscle memory. ⌘⌥ is the least-claimed modifier combo on macOS.
- **Immediate-apply** — mac-native, and lets users see appearance / frosted-glass changes live through the popover.
- **No Settings window / status-bar menu** — out of scope; gear in panel is enough.

## Edge cases

- **Login-item registration denied** — `SMAppService.register()` throws; store catches, reverts toggle to `false`, inline error: *"Could not enable — check System Settings › Login Items."*
- **Hotkey already taken** — `RegisterEventHotKey` returns non-zero `OSStatus`; recorder shows *"Shortcut unavailable"* and keeps the previous binding.
- **Hotkey escape/cancel** — `Esc` during capture cancels; `Clear` button unbinds entirely (panel then only openable via menu-bar icon).
- **Appearance flicker on launch** — applied in `applicationWillFinishLaunching` to avoid a flash of system theme.
- **Frosted-glass live toggle** — posted via `Notification`; `FloatingPanel` swaps its background view in place rather than rebuilding.

## Testing

- `SettingsStoreTests` — round-trip each property through UserDefaults; default values correct on empty store; `Shortcut` JSON-decodes legacy payloads.
- `HotkeyManagerTests` — smoke test that `rebind(nil)` unregisters cleanly; rebind replaces previous binding (mock the Carbon call if practical, otherwise manual).
- Manual QA checklist:
  - Appearance switch reflects instantly in panel + popover.
  - Login item toggle survives reboot.
  - Frosted glass on/off visibly changes the panel background. Not shipped.
  - Hotkey triggers toggle from another focused app.
  - `Esc` / `Clear` behave in the recorder.
  - Denying Login Items in System Settings reverts the toggle on next launch.

## Rollout

No migration needed. The shipped settings keys are `settings.appearance`, `settings.launchAtLogin`, and `settings.hotkey`.
