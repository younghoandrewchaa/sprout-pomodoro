# Break Timer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable break timer that auto-activates after focus ends, with distinct green visual treatment in the menu bar and popup.

**Architecture:** A `TimerMode` enum is added to `TimerViewModel.swift`. The ViewModel becomes mode-aware — `durationSeconds`, `reset()`, and `tick()` all branch on the current mode. On finish, `tick()` flips the mode and resets the timer; `onFinish` passes the completed mode to the caller for notification routing.

**Tech Stack:** Swift, SwiftUI, AppStorage (UserDefaults), XCTest, macOS MenuBarExtra

---

## File Map

| File | Change |
|------|--------|
| `sprout-pomodoro/TimerViewModel.swift` | Add `TimerMode` enum, `mode` property, `breakDurationMinutes`, mode-aware `durationSeconds`, `skipToBreak()`, updated `tick()` and `onFinish` |
| `sprout-pomodoro/NotificationManager.swift` | Rename `sendTimerFinishedNotification()` → `sendFocusFinishedNotification()`, add `sendBreakFinishedNotification()` |
| `sprout-pomodoro/sprout_pomodoroApp.swift` | Route `onFinish` by completed mode |
| `sprout-pomodoro/MenuBarView.swift` | Add mode label, green progress tint, "Skip to Break" link |
| `sprout-pomodoro/TimerMenuBarLabel.swift` | Green capsule when break is running |
| `sprout-pomodoro/SettingsView.swift` | Add break duration picker |
| `sprout-pomodoroTests/sprout_pomodoroTests.swift` | Update `onFinish` closure syntax, add mode tests |

---

## Chunk 1: TimerViewModel core changes + tests

### Task 1: Add TimerMode enum and new properties to TimerViewModel

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`

- [ ] **Step 1: Replace the full contents of `TimerViewModel.swift`**

`durationSeconds` is now mode-aware, which means `reset()` automatically works in both modes without any explicit changes — it already calls `durationSeconds`. `Equatable` conformance is added to the enum here so the file compiles throughout.

```swift
//
//  TimerViewModel.swift
//  sprout-pomodoro
//

import SwiftUI
import Combine

enum TimerMode: Equatable {
    case focus
    case breakTime
}

@MainActor
final class TimerViewModel: ObservableObject {
    @AppStorage("timerDurationMinutes") var timerDurationMinutes: Int = 20 {
        didSet {
            if !isRunning && mode == .focus {
                remainingSeconds = durationSeconds
            }
        }
    }

    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5 {
        didSet {
            if !isRunning && mode == .breakTime {
                remainingSeconds = durationSeconds
            }
        }
    }

    @Published var mode: TimerMode = .focus
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false

    var onFinish: ((TimerMode) -> Void)?

    private var cancellable: AnyCancellable?

    var durationSeconds: Int {
        switch mode {
        case .focus: return timerDurationMinutes * 60
        case .breakTime: return breakDurationMinutes * 60
        }
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        let savedMinutes = UserDefaults.standard.integer(forKey: "timerDurationMinutes")
        let minutes = savedMinutes > 0 ? savedMinutes : 20
        self.remainingSeconds = minutes * 60
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        isRunning = false
        cancellable?.cancel()
        cancellable = nil
    }

    func reset() {
        pause()
        remainingSeconds = durationSeconds
    }

    func skipToBreak() {
        guard mode == .focus else { return }
        pause()
        mode = .breakTime
        remainingSeconds = durationSeconds
    }

    func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            let completedMode = mode
            pause()
            mode = completedMode == .focus ? .breakTime : .focus
            remainingSeconds = durationSeconds
            onFinish?(completedMode)
        }
    }
}
```

- [ ] **Step 2: Add `skipToBreak()` method and update `tick()` — already included above**

(Both are included in the full file replacement in Step 1. No separate action needed.)

```swift
    func skipToBreak() {
        guard mode == .focus else { return }
        pause()
        mode = .breakTime
        remainingSeconds = durationSeconds
    }

    func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            let completedMode = mode
            pause()
            mode = completedMode == .focus ? .breakTime : .focus
            remainingSeconds = durationSeconds
            onFinish?(completedMode)
        }
    }
```

- [ ] **Step 4: Verify the file compiles**

Build the project (Cmd+B in Xcode, or):
```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(error:|warning:|BUILD)"
```
Expected: `BUILD SUCCEEDED` (there will be compile errors in `sprout_pomodoroApp.swift` for the old `onFinish` closure — that's expected and fixed in Task 3)

---

### Task 2: Update tests for TimerViewModel

**Files:**
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Fix the existing `onFinish` test to use the new signature**

The existing `test_tick_whenReachesZero_callsOnFinish` passes a zero-argument closure. Update it to accept the `TimerMode` parameter:

```swift
    func test_tick_whenReachesZero_callsOnFinish() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 1
        var finished = false
        vm.onFinish = { _ in finished = true }
        vm.start()
        vm.tick()
        XCTAssertTrue(finished)
    }
```

- [ ] **Step 2: Add new mode tests**

Append these test methods to the `TimerViewModelTests` class:

```swift
    // MARK: - Mode tests

    func test_initialMode_isFocus() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.mode, .focus)
    }

    func test_durationSeconds_inFocusMode_usesFocusDuration() {
        let vm = TimerViewModel()
        vm.timerDurationMinutes = 25
        XCTAssertEqual(vm.durationSeconds, 25 * 60)
    }

    func test_durationSeconds_inBreakMode_usesBreakDuration() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.breakDurationMinutes = 5
        XCTAssertEqual(vm.durationSeconds, 5 * 60)
    }

    func test_skipToBreak_switchesToBreakMode() {
        let vm = TimerViewModel()
        vm.skipToBreak()
        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_skipToBreak_resetsRemainingToBreakDuration() {
        let vm = TimerViewModel()
        vm.breakDurationMinutes = 5
        vm.skipToBreak()
        XCTAssertEqual(vm.remainingSeconds, 5 * 60)
    }

    func test_skipToBreak_pausesTimer() {
        let vm = TimerViewModel()
        vm.start()
        vm.skipToBreak()
        XCTAssertFalse(vm.isRunning)
    }

    func test_skipToBreak_whenAlreadyInBreak_isNoOp() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.breakDurationMinutes = 5
        vm.remainingSeconds = 60  // partially elapsed
        vm.skipToBreak()
        // mode unchanged, remainingSeconds unchanged
        XCTAssertEqual(vm.mode, .breakTime)
        XCTAssertEqual(vm.remainingSeconds, 60)
    }

    func test_reset_inBreakMode_staysInBreakMode() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.breakDurationMinutes = 5
        vm.remainingSeconds = 30
        vm.reset()
        XCTAssertEqual(vm.mode, .breakTime)
        XCTAssertEqual(vm.remainingSeconds, 5 * 60)
    }

    func test_tick_whenFocusEnds_switchesToBreakMode() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_tick_whenFocusEnds_callsOnFinishWithFocusMode() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 1
        var completedMode: TimerMode?
        vm.onFinish = { completedMode = $0 }
        vm.start()
        vm.tick()
        XCTAssertEqual(completedMode, .focus)
    }

    func test_tick_whenFocusEnds_resetsToBreakDuration() {
        let vm = TimerViewModel()
        vm.breakDurationMinutes = 5
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, 5 * 60)
        XCTAssertFalse(vm.isRunning)
    }

    func test_tick_whenBreakEnds_switchesToFocusMode() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.mode, .focus)
    }

    func test_tick_whenBreakEnds_callsOnFinishWithBreakMode() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        var completedMode: TimerMode?
        vm.onFinish = { completedMode = $0 }
        vm.start()
        vm.tick()
        XCTAssertEqual(completedMode, .breakTime)
    }

    func test_tick_whenBreakEnds_resetsToFocusDuration() {
        let vm = TimerViewModel()
        vm.timerDurationMinutes = 25
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, 25 * 60)
        XCTAssertFalse(vm.isRunning)
    }
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' -only-testing:"sprout-pomodoroTests/TimerViewModelTests" 2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

Expected: All existing tests pass. All new mode tests pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
git add sprout-pomodoro/TimerViewModel.swift sprout-pomodoroTests/sprout_pomodoroTests.swift
git commit -m "feat: add break timer mode to TimerViewModel with tests"
```

---

## Chunk 2: Notifications + App wiring

### Task 3: Update NotificationManager

**Files:**
- Modify: `sprout-pomodoro/NotificationManager.swift`

- [ ] **Step 1: Rename the existing method and add the break notification**

Replace the full contents of `NotificationManager.swift`:

```swift
//
//  NotificationManager.swift
//  sprout-pomodoro
//

import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendFocusFinishedNotification() {
        send(title: "Focus Complete!", body: "Time to take a break.")
    }

    func sendBreakFinishedNotification() {
        send(title: "Break Over!", body: "Time to get back to work.")
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: A compile error in `sprout_pomodoroApp.swift` referencing `sendTimerFinishedNotification` — **this is expected and intentional**. The error is fixed in Task 4. Do not abort; proceed to Task 4.

---

### Task 4: Wire onFinish in the app

**Files:**
- Modify: `sprout-pomodoro/sprout_pomodoroApp.swift`

- [ ] **Step 1: Read the file to confirm the exact text before editing**

```bash
cat /Users/youngho.chaa/github/sprout-pomodoro/sprout-pomodoro/sprout_pomodoroApp.swift
```

Confirm you see the `onFinish` closure with `sendTimerFinishedNotification()` before proceeding.

- [ ] **Step 2: Update the onFinish closure to route by mode**

In `sprout_pomodoroApp.swift`, replace:

```swift
                timerViewModel.onFinish = {
                    NotificationManager.shared.sendTimerFinishedNotification()
                }
```

With:

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

- [ ] **Step 3: Build and run all tests**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All tests pass, BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
git add sprout-pomodoro/NotificationManager.swift sprout-pomodoro/sprout_pomodoroApp.swift
git commit -m "feat: route focus/break notifications by completed mode"
```

---

## Chunk 3: UI updates

### Task 5: Update MenuBarView

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift`

- [ ] **Step 1: Add mode label and green progress tint**

Replace the `VStack` content in `MenuBarView.swift`:

```swift
    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.mode == .focus ? "Focus" : "Break")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(viewModel.mode == .focus ? Color.orange : Color.green)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .monospacedDigit()

            ProgressView(
                value: Double(viewModel.durationSeconds - viewModel.remainingSeconds),
                total: Double(viewModel.durationSeconds)
            )
            .progressViewStyle(.linear)
            .tint(
                viewModel.isRunning
                    ? (viewModel.mode == .focus ? .orange : .green)
                    : .secondary
            )

            HStack(spacing: 16) {
                Button(action: viewModel.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Reset")

                if viewModel.isRunning {
                    Button(action: viewModel.pause) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.mode == .focus ? .orange : .green)
                    }
                    .buttonStyle(.plain)
                    .help("Pause")
                } else {
                    Button(action: viewModel.start) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Start")
                }

                Color.clear
                    .frame(width: 24, height: 24)
            }

            if viewModel.mode == .focus && !viewModel.isRunning {
                Button("Skip to Break") {
                    viewModel.skipToBreak()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.callout)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .font(.callout)
            }
        }
        .padding(20)
        .frame(width: 260)
    }
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: BUILD SUCCEEDED.

---

### Task 6: Update TimerMenuBarLabel

**Files:**
- Modify: `sprout-pomodoro/TimerMenuBarLabel.swift`

- [ ] **Step 1: Add green capsule for break mode**

In `TimerMenuBarLabel.swift`, update the `background` modifier to branch on mode:

```swift
        .background {
            if viewModel.isRunning {
                Capsule().fill(viewModel.mode == .focus ? Color.orange : Color.green)
            }
        }
```

- [ ] **Step 2: Build**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: BUILD SUCCEEDED.

---

### Task 7: Update SettingsView

**Files:**
- Modify: `sprout-pomodoro/SettingsView.swift`

- [ ] **Step 1: Add break duration picker**

Replace the full `SettingsView.swift`:

```swift
//
//  SettingsView.swift
//  sprout-pomodoro
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TimerViewModel

    private let durationOptions = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        Form {
            Section {
                Picker("Focus Duration", selection: $viewModel.timerDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)

                Picker("Break Duration", selection: $viewModel.breakDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Pomodoro Settings")
            } footer: {
                Text("Changing focus duration resets the focus timer. Changing break duration resets the break timer.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 220)  // increased from 150 to fit two pickers
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerViewModel())
}
```

- [ ] **Step 2: Run all tests and build**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All tests pass, BUILD SUCCEEDED.

- [ ] **Step 3: Commit all UI changes**

```bash
cd /Users/youngho.chaa/github/sprout-pomodoro
git add sprout-pomodoro/MenuBarView.swift sprout-pomodoro/TimerMenuBarLabel.swift sprout-pomodoro/SettingsView.swift
git commit -m "feat: add break mode UI — mode label, green capsule, skip link, break duration setting"
```
