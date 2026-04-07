# Daily Stats Refresh on Menu Open — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh today's session stats every time the menu bar popup opens so stale yesterday data is never shown.

**Architecture:** Remove `private` from `refreshTodaySessions()` in `TimerViewModel` so the view can call it directly. In `MenuBarView.onAppear`, call it unconditionally after `setupIfNeeded` — the setup guard already ensures `modelContext` is wired before the fetch runs.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest

---

## Files

- Modify: `sprout-pomodoro/TimerViewModel.swift` — make `refreshTodaySessions()` internal
- Modify: `sprout-pomodoro/MenuBarView.swift` — call `refreshTodaySessions()` on every `onAppear`
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift` — add test for direct call filtering yesterday's sessions

---

### Task 1: Write a failing test for direct `refreshTodaySessions()` call

**Files:**
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Add test at the bottom of `FocusSessionTests`**

Open `sprout-pomodoroTests/sprout_pomodoroTests.swift` and add this test after `test_refreshTodaySessions_excludesPreviousDaySessions` (around line 383), inside the `FocusSessionTests` class, before the closing `}`:

```swift
func test_refreshTodaySessions_directCall_excludesYesterdaySessions() throws {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    context.insert(FocusSession(startedAt: yesterday, durationSeconds: 20 * 60))
    try context.save()

    vm.refreshTodaySessions()

    XCTAssertEqual(vm.dailyFocusSessions, 0)
}
```

- [ ] **Step 2: Run test to confirm it fails to compile**

In Xcode: Product → Test (⌘U), or from terminal:

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/FocusSessionTests/test_refreshTodaySessions_directCall_excludesYesterdaySessions \
  2>&1 | grep -E "(error:|FAILED|PASSED)"
```

Expected: compile error — `'refreshTodaySessions' is inaccessible due to 'private' protection level`

---

### Task 2: Make `refreshTodaySessions()` internal

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift:64`

- [ ] **Step 1: Remove `private` from the method**

In `sprout-pomodoro/TimerViewModel.swift`, change line 64:

```swift
// Before
private func refreshTodaySessions() {

// After
func refreshTodaySessions() {
```

- [ ] **Step 2: Run the new test to confirm it now passes**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/FocusSessionTests/test_refreshTodaySessions_directCall_excludesYesterdaySessions \
  2>&1 | grep -E "(error:|FAILED|PASSED)"
```

Expected: `PASSED`

- [ ] **Step 3: Run the full test suite to confirm no regressions**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|FAILED|PASSED|Test Suite)"
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add sprout-pomodoro/TimerViewModel.swift sprout-pomodoroTests/sprout_pomodoroTests.swift
git commit -m "feat: expose refreshTodaySessions for external call on menu open"
```

---

### Task 3: Call `refreshTodaySessions()` on every menu open

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift:139-149`

- [ ] **Step 1: Add the refresh call in `onAppear`**

In `sprout-pomodoro/MenuBarView.swift`, change the `onAppear` block (lines 139–149):

```swift
// Before
.onAppear {
    viewModel.setupIfNeeded(context: modelContext) { completedMode in
        switch completedMode {
        case .focus:
            NotificationManager.shared.sendFocusFinishedNotification()
        case .breakTime:
            NotificationManager.shared.sendBreakFinishedNotification()
        }
    }
    updateChecker.startPeriodicChecks()
}

// After
.onAppear {
    viewModel.setupIfNeeded(context: modelContext) { completedMode in
        switch completedMode {
        case .focus:
            NotificationManager.shared.sendFocusFinishedNotification()
        case .breakTime:
            NotificationManager.shared.sendBreakFinishedNotification()
        }
    }
    viewModel.refreshTodaySessions()
    updateChecker.startPeriodicChecks()
}
```

- [ ] **Step 2: Build the app to confirm it compiles**

```bash
xcodebuild build \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run the full test suite**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|FAILED|PASSED|Test Suite)"
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift
git commit -m "fix: refresh daily stats every time menu bar popup opens"
```
