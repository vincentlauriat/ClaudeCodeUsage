import Foundation

/// Aggregate stats for the currently filtered set of usage events (the stat cards row).
struct UsageSummary {
    var sessionCount: Int = 0
    var turnCount: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var estimatedCostUSD: Double = 0
}
