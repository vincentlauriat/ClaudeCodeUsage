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
        case .input: Theme.adaptive(light: (0.16, 0.36, 0.65), dark: (0.36, 0.56, 0.85))
        case .output: Theme.adaptive(light: (0.72, 0.30, 0.18), dark: (0.85, 0.47, 0.35))
        case .cacheRead: Theme.adaptive(light: (0.20, 0.45, 0.30), dark: (0.42, 0.62, 0.51))
        case .cacheCreation: Theme.adaptive(light: (0.62, 0.48, 0.10), dark: (0.80, 0.67, 0.30))
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

    /// Which of the daily chart's two independent Y axes this series is scaled against (see
    /// `DailyUsageChartView`): Cache Read/Creation share a left "millions" axis, Input/Output
    /// share a right "hundreds of thousands" axis — reproducing the reference dashboard's
    /// original two-axis look.
    var isCacheAxis: Bool {
        switch self {
        case .cacheRead, .cacheCreation: true
        case .input, .output: false
        }
    }
}
