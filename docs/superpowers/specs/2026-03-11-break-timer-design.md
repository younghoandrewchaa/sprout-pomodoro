# Break Timer Design

**Date:** 2026-03-11
**Status:** Approved

## Overview

Add a break timer to the Sprout Pomodoro macOS menu bar app. The app currently has a single focus timer. This adds a break mode (default 5 min, configurable) that activates after focus ends, with distinct visual treatment in the menu bar and popup.

## Behaviour

- Two modes: **focus** and **break**
- Only one timer runs at a time
- When focus ends: send "Focus complete" notification, switch to break mode, reset break timer to break duration, leave paused
- When break ends: send "Break over" notification, switch to focus mode, reset focus timer, leave paused
- User starts each timer manually with the play button
- A "Skip to Break" link appears in the popup when in focus mode and the timer is not running, allowing manual mode switch without waiting for focus to end

## Architecture

### TimerMode enum

```swift
enum TimerMode {
    case focus
    case breakTime
}
```

### TimerViewModel changes

- Add `@Published var mode: TimerMode = .focus`
- Add `@AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5`
- `durationSeconds` becomes mode-aware:
  - `.focus` → `timerDurationMinutes * 60`
  - `.breakTime` → `breakDurationMinutes * 60`
- `reset()` resets to current mode's duration (no mode change)
- `skipToBreak()` switches mode to `.breakTime` and resets — only valid when in focus mode
- `onFinish: ((TimerMode) -> Void)?` — callback receives the mode that just completed so the caller can route the correct notification

On finish (inside `tick()`): pause, flip mode, reset `remainingSeconds`, call `onFinish` with the completed mode.

When `breakDurationMinutes` changes and timer is not running and mode is `.breakTime`, reset `remainingSeconds`. Same existing pattern as `timerDurationMinutes`.

## UI

### MenuBarView

- Add a small mode label ("Focus" / "Break") above the time display
- Progress bar tint: orange for focus, green for break
- "Skip to Break" link below controls: visible only when `mode == .focus && !isRunning`
- Play button and reset button unchanged

### TimerMenuBarLabel

- Running focus: orange capsule (existing behaviour)
- Running break: green capsule
- Not running: no capsule (existing behaviour)

### SettingsView

- Add a "Break Duration" picker under the existing "Pomodoro Settings" section
- Same duration options: `[5, 10, 15, 20, 25, 30, 45, 60]` minutes
- Bound to `viewModel.breakDurationMinutes`
- Footer note: "Changing break duration resets the break timer."
- Increase form height to accommodate second picker

### NotificationManager

- Rename `sendTimerFinishedNotification()` to `sendFocusFinishedNotification()`
  - Title: "Focus Complete!", body: "Time to take a break."
- Add `sendBreakFinishedNotification()`
  - Title: "Break Over!", body: "Time to get back to work."

### SproutPomodoroApp wiring

```swift
timerViewModel.onFinish = { completedMode in
    switch completedMode {
    case .focus:
        NotificationManager.shared.sendFocusFinishedNotification()
    case .breakTime:
        NotificationManager.shared.sendBreakFinishedNotification()
    }
}
```

## Files Changed

| File | Change |
|------|--------|
| `TimerViewModel.swift` | Add `TimerMode`, mode property, break duration, mode-aware logic |
| `TimerMenuBarLabel.swift` | Green capsule when break is running |
| `MenuBarView.swift` | Mode label, green progress tint, skip link |
| `SettingsView.swift` | Break duration picker, taller frame |
| `NotificationManager.swift` | Rename focus notification, add break notification |
| `sprout_pomodoroApp.swift` | Route `onFinish` by completed mode |

## Out of Scope

- Long break (4th Pomodoro pattern)
- Pomodoro count tracking
- Sound effects on timer end
- Auto-starting break timer (user starts manually)
