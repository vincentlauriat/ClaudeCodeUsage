import Foundation

/// Aggregate usage for one hour-of-day (0...23) on a specific calendar day — feeds the
/// "Cost per hour" card, which compares today's activity so far against yesterday's.
struct HourlyUsage: Identifiable {
    var id: Int { hour }
    let hour: Int
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var estimatedCostUSD: Double = 0
}
