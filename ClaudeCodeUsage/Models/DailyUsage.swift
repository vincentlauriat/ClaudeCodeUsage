import Foundation

/// Aggregate token usage for a single calendar day, used by the daily chart.
struct DailyUsage: Identifiable {
    var id: Date { day }
    let day: Date
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0

    var total: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }
}
