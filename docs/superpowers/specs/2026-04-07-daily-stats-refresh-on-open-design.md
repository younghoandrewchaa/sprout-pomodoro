# Daily Stats Refresh on Menu Open

**Date:** 2026-04-07

## Problem

When the app stays open overnight, `todaySessions` holds the previous day's data in memory. `refreshTodaySessions()` is only called once at setup (guarded by `isSetUp`) and again after a focus session completes. If the user opens the menu bar popup on a new day, they see yesterday's stats until a session finishes.

## Goal

Show accurate today-only stats the moment the user opens the menu bar popup.

## Design

### Change 1 — `TimerViewModel.swift`

Make `refreshTodaySessions()` internal (remove `private`) so `MenuBarView` can call it directly.

```swift
// Before
private func refreshTodaySessions() { ... }

// After
func refreshTodaySessions() { ... }
```

### Change 2 — `MenuBarView.swift`

Call `viewModel.refreshTodaySessions()` on every `onAppear`, after `setupIfNeeded` (which ensures `modelContext` is wired before the fetch runs).

```swift
.onAppear {
    viewModel.setupIfNeeded(context: modelContext) { completedMode in
        ...
    }
    viewModel.refreshTodaySessions()   // always refresh on open
    updateChecker.startPeriodicChecks()
}
```

### Why this works

- `setupIfNeeded` is still the one-time gate for wiring context and callback.
- `refreshTodaySessions()` re-fetches from SwiftData using `startOfDay(for: Date())` each time, so it always returns only today's sessions regardless of what day the app was last used.
- The fetch is cheap; no date tracking or background timers needed.

## Out of scope

- Refreshing stats in the background when the popup is closed.
- Persisting or caching the last-seen date.
