//
//  UpdateChecker.swift
//  sprout-pomodoro
//
//  Created by Youngho Chaa on 01/04/2026.
//

import Foundation
import Combine

struct AvailableUpdate {
    let version: String
    let url: URL
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AvailableUpdate?
    
    private let appVersion: String
    private let fetcher: (URL) async throws -> Data
    private var hasStarted = false
    
    init(
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
        fetcher: @escaping (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.appVersion = appVersion
        self.fetcher = fetcher
    }
    
    static func parseVersion(_ string: String) -> [Int] {
        let stripped = string.hasPrefix("v") ? String(string.dropFirst()) : string
        return stripped.split(separator: ".").compactMap { Int($0)}
    }
    
    static func isNewer(_ tagVersion: [Int], than appVersion: [Int]) -> Bool {
        let maxLen = max(tagVersion.count, appVersion.count)
        let t = tagVersion + Array(repeating: 0, count: maxLen - tagVersion.count)
        let a = appVersion + Array(repeating: 0, count: maxLen - appVersion.count)
        for (tv, av) in zip(t, a) {
            if tv > av { return true }
            if tv < av { return false }
        }
        return false
    }
}
