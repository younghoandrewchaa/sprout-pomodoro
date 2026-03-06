# Fix Settings Link Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the non-responsive Settings button in the MenuBarExtra popover.

**Root Cause:** `SettingsLink` sends `showSettingsWindow:` through AppKit's responder chain. Inside a `MenuBarExtra` `.window`-style popover (`NSPanel`), the panel is isolated from the main app's responder chain where SwiftUI registers the `Settings` scene handler. The action gets lost. `LSUIElement = YES` (accessory mode) compounds this — the app is never "active" in the NSApplication sense, so even if the action reached NSApp it might not respond.

**Fix:** Replace `SettingsLink` with a plain `Button` that directly calls `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` after activating the app. This bypasses the broken responder chain entirely.

**Tech Stack:** SwiftUI, AppKit (NSApp)

---

### Task 1: Replace SettingsLink with a direct NSApp action call

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift:57-60`

**Step 1: Update MenuBarView to use a Button instead of SettingsLink**

In `MenuBarView.swift`, replace:

```swift
SettingsLink {
    Label("Settings", systemImage: "gear")
        .font(.callout)
}
```

With:

```swift
Button {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
} label: {
    Label("Settings", systemImage: "gear")
        .font(.callout)
}
.buttonStyle(.plain)
```

- `NSApp.activate(ignoringOtherApps: true)` — brings the app into the foreground so the Settings window can receive focus and keyboard input
- `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` — directly invokes the action on NSApp, bypassing the broken responder chain in the MenuBarExtra panel

**Step 2: Build and run**

In Xcode: Cmd+R
1. Click the menu bar icon → popover opens
2. Click "Settings" → Settings window should open immediately
3. Verify the Settings window shows the duration picker
4. Verify Cmd+, also opens Settings (this is handled by macOS automatically for the `Settings` scene)

**Step 3: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift
git commit -m "fix: replace SettingsLink with direct NSApp action to fix unresponsive settings button"
```
