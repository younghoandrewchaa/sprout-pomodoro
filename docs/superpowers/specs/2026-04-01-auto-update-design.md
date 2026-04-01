# Auto-Update Feature Design

**Date:** 2026-04-01  
**Status:** Approved

## Overview

Add a lightweight auto-update check to Sprout Pomodoro. When a newer version is published on GitHub Releases, the app shows a native alert prompting the user to update. Clicking "Update" opens the release page in the browser. No download or install automation — the user downloads manually from GitHub.

## Distribution Context

- Distributed via **GitHub Releases** (not the App Store)
- Repo: `andrewchaa/sprout-pomodoro`
- Current version stored in `CFBundleShortVersionString` (e.g. `"1.0"`)
- Releases tagged as `v<major>.<minor>.<patch>` (e.g. `v1.2.0`)

## Architecture

One new file, minimal changes to two existing files:

| File | Change |
|------|--------|
| `UpdateChecker.swift` | New — owns all update logic |
| `sprout_pomodoroApp.swift` | Add `@StateObject var updateChecker`, start periodic checks on init, pass as `.environmentObject` |
| `MenuBarView.swift` | Read `updateChecker` from environment, show `.alert` when update available |

No changes to `SettingsView`, `TimerViewModel`, or `NotificationManager`.

## Components

### `UpdateChecker`

```swift
struct AvailableUpdate {
    let version: String
    let url: URL
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AvailableUpdate?

    init(session: URLSession = .shared)
    func checkForUpdates() async
    func startPeriodicChecks()
}
```

- **Endpoint:** `https://api.github.com/repos/andrewchaa/sprout-pomodoro/releases/latest`
- **Parsed fields:** `tag_name` (e.g. `"v1.2.0"`) and `html_url`
- **Version comparison:** Strip `"v"` prefix, split on `"."`, parse as `[Int]`, zero-pad both arrays to the same length, then compare element-by-element. Example: app `"1.0"` → `[1, 0, 0]` vs tag `"v1.2.0"` → `[1, 2, 0]` → tag is newer.
- **`startPeriodicChecks()`:** Calls `checkForUpdates()` immediately (via `Task`), then schedules a `Timer` every 86,400 seconds (24h)
- **`URLSession` injection:** Passed via `init` to support mocking in tests

### Alert (in `MenuBarView`)

- **Title:** `"Update Available"`
- **Message:** `"Version X.X.X is available. Would you like to update?"`
- **"Update" button:** Opens `html_url` via `NSWorkspace.shared.open(_:)`
- **"Later" button:** Dismisses, sets `availableUpdate = nil`

## Data Flow

```
App launch
  └─ SproutPomodoroApp.init()
       └─ updateChecker.startPeriodicChecks()
            ├─ Task { await checkForUpdates() }   ← immediate
            └─ Timer(every: 86400s)
                 └─ Task { await checkForUpdates() }   ← periodic

checkForUpdates()
  ├─ GET /repos/andrewchaa/sprout-pomodoro/releases/latest
  ├─ Decode { tag_name, html_url }
  ├─ Parse version from tag_name
  ├─ Compare with CFBundleShortVersionString
  └─ If newer → set availableUpdate
                  └─ MenuBarView .alert fires via SwiftUI binding
```

## Error Handling

All failures are swallowed silently — no error alert shown to the user:

- Network error (no connection, timeout)
- Non-2xx HTTP response
- JSON decode failure
- Malformed version string

Rationale: Update checks are background housekeeping. Surfacing errors would be disruptive and actionable by the user.

## Testing

File: `sprout-pomodoroTests/UpdateCheckerTests.swift`

`URLSession` is injected so tests use a mock without hitting the network.

| Test | Scenario |
|------|----------|
| `test_newerVersion_setsAvailableUpdate` | Tag `v2.0.0`, app is `1.0` → `availableUpdate` is set |
| `test_sameVersion_doesNotSetAvailableUpdate` | Tag `v1.0.0`, app is `1.0` → `availableUpdate` stays nil |
| `test_olderVersion_doesNotSetAvailableUpdate` | Tag `v0.9.0`, app is `1.0` → `availableUpdate` stays nil |
| `test_networkError_doesNotSetAvailableUpdate` | URLSession throws → `availableUpdate` stays nil |
| `test_parseVersion_handlesVPrefix` | `"v1.2.3"` parses to `[1, 2, 3]` |
| `test_parseVersion_handlesTwoComponents` | `"1.0"` parses to `[1, 0]` |

## Files Summary

| Action | File |
|--------|------|
| Create | `sprout-pomodoro/UpdateChecker.swift` |
| Modify | `sprout-pomodoro/sprout_pomodoroApp.swift` |
| Modify | `sprout-pomodoro/MenuBarView.swift` |
| Create | `sprout-pomodoroTests/UpdateCheckerTests.swift` |
