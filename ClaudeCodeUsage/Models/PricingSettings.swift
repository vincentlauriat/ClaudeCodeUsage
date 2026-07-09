import Foundation

/// User-editable pricing for the 4 model families, persisted in `UserDefaults`. `.default`
/// matches Anthropic's published per-model input rate, with output/cache-write/cache-read
/// derived via the ratios that hold across every current model: output = 5x input,
/// cache write (5m TTL) = 1.25x input, cache read = 0.1x input.
struct PricingSettings: Codable, Equatable {
    var opus: ModelPricing
    var sonnet: ModelPricing
    var haiku: ModelPricing
    var fable: ModelPricing

    static let `default` = PricingSettings(
        // Opus 4.8: $5/$25 per MTok.
        opus: ModelPricing(inputPerMTok: 5, outputPerMTok: 25, cacheWritePerMTok: 6.25, cacheReadPerMTok: 0.50),
        // Sonnet 5 standard rate: $3/$15 per MTok (ignores the $2/$10 intro rate through 2026-08-31).
        sonnet: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30),
        // Haiku 4.5: $1/$5 per MTok.
        haiku: ModelPricing(inputPerMTok: 1, outputPerMTok: 5, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10),
        // Fable 5: $10/$50 per MTok.
        fable: ModelPricing(inputPerMTok: 10, outputPerMTok: 50, cacheWritePerMTok: 12.50, cacheReadPerMTok: 1.00)
    )

    /// Maps a model identifier (e.g. "claude-opus-4-8", "claude-sonnet-5",
    /// "claude-haiku-4-5-20251001") to its pricing family. Falls back to Sonnet for unrecognized
    /// models rather than crashing or under/over-estimating wildly — the single place this
    /// substring matching happens; `pricing(forModel:)` builds on it.
    func family(forModel modelId: String) -> ModelFamily {
        let id = modelId.lowercased()
        if id.contains("opus") { return .opus }
        if id.contains("haiku") { return .haiku }
        if id.contains("fable") { return .fable }
        return .sonnet
    }

    func pricing(forModel modelId: String) -> ModelPricing {
        switch family(forModel: modelId) {
        case .opus: opus
        case .sonnet: sonnet
        case .haiku: haiku
        case .fable: fable
        }
    }

    /// Whether the model id actually named a known family, rather than silently falling back to
    /// the Sonnet default — used by the Insights panel to flag models that need a rate confirmed.
    func hasDedicatedTier(forModel modelId: String) -> Bool {
        let id = modelId.lowercased()
        return id.contains("opus") || id.contains("sonnet") || id.contains("haiku") || id.contains("fable")
    }

    private static let userDefaultsKey = "pricingSettingsV1"

    static func loadFromUserDefaults() -> PricingSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(PricingSettings.self, from: data)
        else { return .default }
        return decoded
    }

    func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
