import Foundation

/// Aggregate of one session's `UsageEvent`s (main conversation + any sub-agent turns sharing the
/// same `sessionId`), for the sessions list.
struct SessionSummary: Identifiable {
    let id: String // sessionId
    let displayName: String
    let cwd: String
    let firstSeen: Date
    let lastSeen: Date
    let turnCount: Int
    let modelsUsed: [String]
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let estimatedCostUSD: Double

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    init?(sessionId: String, events: [UsageEvent], info: SessionInfo?) {
        guard let first = events.first else { return nil }
        self.id = sessionId
        self.displayName = info?.displayName(fallback: sessionId) ?? String(sessionId.prefix(8))
        self.cwd = info?.cwd ?? first.cwd
        self.firstSeen = events.map(\.timestamp).min() ?? first.timestamp
        self.lastSeen = events.map(\.timestamp).max() ?? first.timestamp
        self.turnCount = events.count
        self.modelsUsed = Array(Set(events.map(\.model))).sorted()
        self.inputTokens = events.reduce(0) { $0 + $1.inputTokens }
        self.outputTokens = events.reduce(0) { $0 + $1.outputTokens }
        self.cacheCreationTokens = events.reduce(0) { $0 + $1.cacheCreationTokens }
        self.cacheReadTokens = events.reduce(0) { $0 + $1.cacheReadTokens }
        self.estimatedCostUSD = PricingCalculator.estimatedCostUSD(for: events)
    }
}
