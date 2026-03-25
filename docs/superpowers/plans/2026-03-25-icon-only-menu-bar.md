# Icon-Only Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show only a colored icon in the menu bar (no time text) — orange for focus, green for break, white when idle/time-up.

**Architecture:** The color logic already exists in `TimerMenuBarLabel`. The only change is removing the `Text` element from the `HStack` and cleaning up the now-unnecessary layout modifiers.

**Tech Stack:** SwiftUI, AppKit, `ImageRenderer` for menu bar icon rendering.

---

## File Map

- Modify: `sprout-pomodoro/TimerMenuBarLabel.swift` — remove time text, keep colored icon only

---

### Task 1: Remove time text, show icon-only with correct colors

**Context:**

Current `TimerMenuBarLabel.body`:
```swift
HStack(spacing: 4) {
    Image(systemName: "timer")
        .symbolEffect(.pulse, isActive: viewModel.isRunning)
    Text(viewModel.formattedTime)   // <-- remove this
        .monospacedDigit()
        .font(.system(size: 12, weight: .medium))
}
.foregroundStyle(
    viewModel.isRunning
        ? (viewModel.mode == .focus ? Color.orange : Color.green)
        : .white
)
.padding(.horizontal, 10)
.frame(height: 22)
```

The color logic is already correct:
- `isRunning && mode == .focus` → orange
- `isRunning && mode == .breakTime` → green
- `!isRunning` (idle or time up) → white

**Files:**
- Modify: `sprout-pomodoro/TimerMenuBarLabel.swift`

- [ ] **Step 1: Edit `TimerMenuBarLabel.body` to remove the `Text` and simplify layout**

Replace the `body` with:

```swift
var body: some View {
    Image(systemName: "timer")
        .symbolEffect(.pulse, isActive: viewModel.isRunning)
        .foregroundStyle(
            viewModel.isRunning
                ? (viewModel.mode == .focus ? Color.orange : Color.green)
                : .white
        )
        .font(.system(size: 14))
        .frame(width: 22, height: 22)
}
```

- [ ] **Step 2: Build and verify in Xcode**

Run the app. Check that:
- Menu bar shows only the icon (no time text)
- Icon is orange while focus timer is running
- Icon is green while break timer is running
- Icon is white when timer is stopped or time is up
- Icon pulses while timer is running

- [ ] **Step 3: Commit**

```bash
git add sprout-pomodoro/TimerMenuBarLabel.swift
git commit -m "feat: show icon-only in menu bar with state-based color"
```
