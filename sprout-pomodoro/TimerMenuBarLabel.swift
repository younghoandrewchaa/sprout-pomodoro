//
//  TimerMenuBarLabel.swift
//  sprout-pomodoro
//

import SwiftUI

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
    }
}
