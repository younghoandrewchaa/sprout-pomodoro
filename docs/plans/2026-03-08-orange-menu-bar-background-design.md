# Orange Menu Bar Background — Design

**Date:** 2026-03-08

## Problem

`MenuBarExtra` labels render SwiftUI views as static image snapshots per frame. Per-frame values (countdown text) update correctly, but SwiftUI animations and `.background {}` modifiers are stripped by the system. Adding a `.background { Capsule().fill(.orange) }` has no visible effect.

## Solution: ImageRenderer wrapper

Use `ImageRenderer` to bake the full visual state — including the orange capsule background — into an `NSImage` on each render. Since the label already re-renders every second (countdown), the image stays current.

## Changes

### `TimerMenuBarLabel.swift`
Add `RenderedMenuBarLabel`: a wrapper `View` with `@ObservedObject var viewModel` that:
1. Creates `ImageRenderer(content: TimerMenuBarLabel(viewModel: viewModel))`
2. Sets `renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0` for retina
3. Returns `Image(nsImage: renderer.nsImage ?? NSImage())`

`TimerMenuBarLabel` is unchanged — it remains the visual source of truth.

### `sprout_pomodoroApp.swift`
Swap `TimerMenuBarLabel(viewModel: timerViewModel)` → `RenderedMenuBarLabel(viewModel: timerViewModel)` in the `label:` closure.
