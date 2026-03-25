//
//  TimerMenuBarLabel.swift
//  sprout-pomodoro
//

import SwiftUI
import AppKit

struct RenderedMenuBarLabel: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        let renderer = ImageRenderer(content: TimerMenuBarLabel(viewModel: viewModel))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return Image(nsImage: renderer.nsImage ?? NSImage())
    }
}

struct TimerMenuBarLabel: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .symbolEffect(.pulse, isActive: viewModel.isRunning)
        }
        .foregroundStyle(
            viewModel.isRunning
                ? (viewModel.mode == .focus ? Color.orange : Color.green)
                : .white
        )
        .font(.system(size: 14))
        .frame(height: 22)
    }
}
