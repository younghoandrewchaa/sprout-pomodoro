# Cover Green Highlight With Orange Capsule Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the orange capsule in the menu bar label fully cover the green macOS selection highlight that appears when the app is focused.

**Architecture:** The `TimerMenuBarLabel` renders into an `NSImage` via `ImageRenderer`. macOS draws a green selection highlight behind the full bounds of that image. Currently the orange `Capsule` background is smaller than the image bounds (due to `padding` creating transparent outer space), letting the green show through around the edges. Fix: set a fixed height matching macOS's menu bar item height (22pt) and increase horizontal padding so the orange capsule completely fills the image bounds — eliminating transparent areas the green highlight bleeds through.

**Tech Stack:** SwiftUI, AppKit, `ImageRenderer`, `NSImage`

---

### Task 1: Expand the orange capsule to cover the full menu bar item bounds

**Files:**
- Modify: `sprout-pomodoro/TimerMenuBarLabel.swift:22-38`

**Step 1: Understand the current layout**

In `TimerMenuBarLabel`, the view is:
- `HStack` content → `.padding(.horizontal, 6).padding(.vertical, 2)` → `.background { Capsule }`

The orange capsule covers content + padding. The `ImageRenderer` renders the full view as an image. macOS highlights the entire image bounds with green, but since the capsule exactly equals the image bounds in theory... the issue is macOS adds its own inset/padding around the image for the highlight. So the green highlight area is slightly *larger* than our rendered image.

The fix: increase the vertical padding (or use a fixed height frame) so the rendered image is tall enough that the orange capsule covers the green highlight area. A fixed height of `22` points matches the standard macOS menu bar height.

**Step 2: Apply the fix in `TimerMenuBarLabel.swift`**

Change the `.padding(.vertical, 2)` to use a fixed `.frame(height: 22)` instead, which ensures the capsule matches the macOS menu bar item height:

```swift
struct TimerMenuBarLabel: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .symbolEffect(.pulse, isActive: viewModel.isRunning)
            Text(viewModel.formattedTime)
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background {
            if viewModel.isRunning {
                Capsule().fill(Color.orange)
            }
        }
    }
}
```

Key changes:
- Replace `.padding(.vertical, 2)` with `.frame(height: 22)` — fixes vertical coverage
- Increase `.padding(.horizontal, 6)` to `.padding(.horizontal, 8)` — adds a bit more horizontal coverage

**Step 3: Build and visually verify**

Run the app. When the timer is running and the app is focused, the green highlight behind the orange capsule should no longer be visible. The orange pill should appear seamlessly without any green border/glow around it.

**Step 4: If green still bleeds through horizontally**

Try increasing horizontal padding further to `10` or `12`. The right value depends on macOS rendering. Adjust until the orange fully covers the green on all sides.

**Step 5: Commit**

```bash
git add sprout-pomodoro/TimerMenuBarLabel.swift
git commit -m "fix: expand orange capsule to cover macOS green selection highlight"
```
