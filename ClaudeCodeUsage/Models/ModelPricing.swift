import Foundation

/// Per-million-token pricing (USD) for one model family. Editable from the UI (see
/// `PricingSettings`) — these are just the 4 rates plus the cost formula.
struct ModelPricing: Codable, Equatable {
    var inputPerMTok: Double
    var outputPerMTok: Double
    var cacheWritePerMTok: Double
    var cacheReadPerMTok: Double

    func cost(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        let million = 1_000_000.0
        return Double(inputTokens) / million * inputPerMTok
            + Double(outputTokens) / million * outputPerMTok
            + Double(cacheCreationTokens) / million * cacheWritePerMTok
            + Double(cacheReadTokens) / million * cacheReadPerMTok
    }
}
