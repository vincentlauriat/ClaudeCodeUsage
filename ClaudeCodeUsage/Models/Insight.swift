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
            case .critical: Color(red: 0.90, green: 0.35, blue: 0.35)
            case .warning: Color(red: 0.85, green: 0.65, blue: 0.15)
            case .good: Theme.accentGreen
            case .info: Theme.textSecondary
            }
        }
    }

    var id: String { level.rawValue + text }
    let level: Level
    let text: String
}
