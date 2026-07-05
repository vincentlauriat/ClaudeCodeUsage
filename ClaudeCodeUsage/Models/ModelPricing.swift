import Foundation

/// Per-million-token pricing (USD) for one model family.
///
/// There is no local API exposing exact Anthropic pricing, so these are approximations based on
/// the publicly known ratio across model families (output ≈ 5x input, cache write ≈ 1.25x
/// input, cache read ≈ 0.1x input). See `PLAN.md` / `ARCHITECTURE_EN.md` for the assumption.
/// Adjust this table if Anthropic publishes different rates.
struct ModelPricing {
    let inputPerMTok: Double
    let outputPerMTok: Double
    let cacheWritePerMTok: Double
    let cacheReadPerMTok: Double

    static let opus = ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50)
    static let sonnet = ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
    static let haiku = ModelPricing(inputPerMTok: 1, outputPerMTok: 5, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10)
    /// Fable pricing hasn't been published; assume Sonnet-tier until confirmed.
    static let fable = sonnet

    /// Maps a model identifier (e.g. "claude-opus-4-8", "claude-sonnet-5",
    /// "claude-haiku-4-5-20251001") to its pricing tier. Falls back to Sonnet-tier rates for
    /// unrecognized models rather than crashing or under/over-estimating wildly.
    static func forModel(_ modelId: String) -> ModelPricing {
        let id = modelId.lowercased()
        if id.contains("opus") { return .opus }
        if id.contains("haiku") { return .haiku }
        if id.contains("fable") { return .fable }
        if id.contains("sonnet") { return .sonnet }
        return .sonnet
    }

    func cost(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        let million = 1_000_000.0
        return Double(inputTokens) / million * inputPerMTok
            + Double(outputTokens) / million * outputPerMTok
            + Double(cacheCreationTokens) / million * cacheWritePerMTok
            + Double(cacheReadTokens) / million * cacheReadPerMTok
    }
}
