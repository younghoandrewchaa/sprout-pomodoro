# Fix Notification Icon Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the missing app icon in macOS notifications fired when a Pomodoro timer completes.

**Architecture:** For macOS menu bar agent apps (`LSUIElement = YES`), `NSApp.applicationIconImage` is not automatically populated from the app icon asset catalog because the app has no Dock presence. macOS Notification Center reads `NSApp.applicationIconImage` at notification display time — if it is `nil`, the notification renders a broken placeholder. The fix is a single line in `sprout_pomodoroApp.swift`'s `init()` that explicitly loads and assigns the icon image.

**Tech Stack:** SwiftUI, AppKit (`NSApp`), UserNotifications framework.

---

## Root Cause

- `INFOPLIST_KEY_LSUIElement = YES` in `project.pbxproj` configures the app as a background agent with no Dock icon.
- macOS does **not** automatically set `NSApp.applicationIconImage` for agent apps — the property remains `nil`.
- `UNUserNotificationCenter` derives the notification icon from `NSApp.applicationIconImage`; when it is `nil`, macOS renders the broken checkerboard placeholder visible in the screenshot.
- The app icon asset catalog (`Assets.xcassets/AppIcon.appiconset/`) is correctly configured with all required macOS sizes — the image files are present and the `Contents.json` references them properly. No asset-side changes are needed.

---

### Task 1: Set `NSApp.applicationIconImage` at launch

**Files:**
- Modify: `sprout-pomodoro/sprout_pomodoroApp.swift:14-16`

**Step 1: Read the file to confirm current state**

Open `sprout-pomodoro/sprout_pomodoroApp.swift`. The `init()` currently contains only:

```swift
init() {
    NotificationManager.shared.requestPermission()
}
```

**Step 2: Add the icon assignment**

Add one line to `init()` so that `NSApp.applicationIconImage` is set before any notification can be sent:

```swift
init() {
    NSApp.applicationIconImage = NSImage(named: "AppIcon")
    NotificationManager.shared.requestPermission()
}
```

`NSImage(named: "AppIcon")` looks up the named image from the app bundle's asset catalog — the same `AppIcon` asset that `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` compiles into the bundle. This must come before `requestPermission()` to ensure the icon is set as early as possible, though ordering relative to the notification request is not critical.

**Step 3: Build and run**

Build the app in Xcode (Cmd+R). Trigger a timer completion to fire a notification. Confirm the notification now shows the Sprout Pomodoro app icon instead of the broken placeholder.

**Step 4: Commit**

```bash
git add sprout-pomodoro/sprout_pomodoroApp.swift
git commit -m "fix: set NSApp.applicationIconImage so notifications show app icon

LSUIElement agent apps do not auto-populate applicationIconImage from
the asset catalog. Notification Center reads this property to render
the notification icon; nil causes the broken placeholder."
```
