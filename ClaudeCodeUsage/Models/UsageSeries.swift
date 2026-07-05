import SwiftUI

/// The four stacked series shown in the daily usage chart, in bottom-to-top stacking order.
enum UsageSeries: String, CaseIterable, Identifiable {
    case input = "Input"
    case output = "Output"
    case cacheRead = "Cache Read"
    case cacheCreation = "Cache Creation"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .input: Color(red: 0.36, green: 0.56, blue: 0.85)
        case .output: Color(red: 0.85, green: 0.47, blue: 0.35)
        case .cacheRead: Color(red: 0.42, green: 0.62, blue: 0.51)
        case .cacheCreation: Color(red: 0.80, green: 0.67, blue: 0.30)
        }
    }

    func value(from day: DailyUsage) -> Int {
        switch self {
        case .input: day.inputTokens
        case .output: day.outputTokens
        case .cacheRead: day.cacheReadTokens
        case .cacheCreation: day.cacheCreationTokens
        }
    }
}
