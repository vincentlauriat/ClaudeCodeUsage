import SwiftUI

/// One row in the Insights & Alerts panel — a small, automatically-derived signal about the
/// currently filtered usage. See `InsightEngine` for how these are produced.
struct Insight: Identifiable {
    enum Level: String {
        case critical = "Critical"
        case warning = "Warning"
        case good = "Good"
        case info = "Info"

        var color: Color {
            switch self {
            case .critical: Theme.adaptive(light: (0.761, 0.227, 0.227), dark: (0.90, 0.35, 0.35))
            case .warning: Theme.adaptive(light: (0.725, 0.474, 0.039), dark: (0.85, 0.65, 0.15))
            case .good: Theme.accentGreen
            case .info: Theme.textSecondary
            }
        }
    }

    var id: String { level.rawValue + text }
    let level: Level
    let text: String
}
