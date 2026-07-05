import Foundation

/// One assistant turn extracted from a Claude Code transcript, with its token usage.
struct UsageEvent: Identifiable, Hashable {
    let id: String
    let sessionId: String
    let model: String
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var day: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
}
