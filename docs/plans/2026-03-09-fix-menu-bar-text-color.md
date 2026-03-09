# Fix Menu Bar Text Color Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore the menu bar timer text to white in all states (running and idle).

**Architecture:** The menu bar label is rendered off-screen by `ImageRenderer` and displayed as an `NSImage`. `ImageRenderer` renders in a fixed light-mode environment by default, so `foregroundColor(nil)` (the "system default") resolves to black rather than the white expected for a dark menu bar. The fix is to always apply `.foregroundColor(.white)` regardless of timer state.

**Tech Stack:** SwiftUI, AppKit (`ImageRenderer`, `NSImage`).

---

## Root Cause

`TimerMenuBarLabel.swift:30` currently reads:

```swift
.foregroundColor(viewModel.isRunning ? .white : nil)
```

- When **running**: `.white` — correct, white text on orange capsule background.
- When **not running**: `nil` — inherits environment color. Because `ImageRenderer` renders with a light-mode environment by default, `nil` resolves to black, producing illegible dark text on the transparent menu bar.

Previously the color was likely `.white` for all states. The regression was introduced in the "Orange background" commit when the conditional was added.

---

### Task 1: Set foregroundColor to .white unconditionally

**Files:**
- Modify: `sprout-pomodoro/TimerMenuBarLabel.swift:30`

**Step 1: Read the file to confirm current state**

Open `sprout-pomodoro/TimerMenuBarLabel.swift`. Line 30 should read:

```swift
.foregroundColor(viewModel.isRunning ? .white : nil)
```

**Step 2: Apply the fix**

Change line 30 to:

```swift
.foregroundColor(.white)
```

The full `body` after the fix:

```swift
var body: some View {
    HStack(spacing: 4) {
        Image(systemName: "timer")
            .symbolEffect(.pulse, isActive: viewModel.isRunning)
        Text(viewModel.formattedTime)
            .monospacedDigit()
            .font(.system(size: 12, weight: .medium))
    }
    .foregroundColor(.white)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background {
        if viewModel.isRunning {
            Capsule().fill(Color.orange)
        }
    }
}
```

**Step 3: Verify the edit**

Re-read the file and confirm line 30 is `.foregroundColor(.white)` with no conditional.

**Step 4: Build and verify**

Build the app in Xcode (Cmd+B). Check the menu bar — the timer text should be white when idle and white on orange when running.

**Step 5: Commit**

```bash
git add sprout-pomodoro/TimerMenuBarLabel.swift
git commit -m "fix: always render menu bar text in white

ImageRenderer uses a light-mode environment by default, so foregroundColor(nil)
resolves to black. Use .white unconditionally so the label is legible on the
dark menu bar in both idle and running states."
```
