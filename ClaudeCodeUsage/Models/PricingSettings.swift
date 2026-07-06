import Foundation

/// User-editable pricing for the 4 model families, persisted in `UserDefaults`. `.default`
/// matches the rates that used to be hardcoded in `ModelPricing` (Anthropic's known ratios:
/// output ≈ 5x input, cache write ≈ 1.25x input, cache read ≈ 0.1x input).
struct PricingSettings: Codable, Equatable {
    var opus: ModelPricing
    var sonnet: ModelPricing
    var haiku: ModelPricing
    var fable: ModelPricing

    static let `default` = PricingSettings(
        opus: ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50),
        sonnet: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30),
        haiku: ModelPricing(inputPerMTok: 1, outputPerMTok: 5, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10),
        // Fable pricing hasn't been published; assume Sonnet-tier until confirmed.
        fable: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
    )

    /// Maps a model identifier (e.g. "claude-opus-4-8", "claude-sonnet-5",
    /// "claude-haiku-4-5-20251001") to its pricing tier. Falls back to Sonnet-tier rates for
    /// unrecognized models rather than crashing or under/over-estimating wildly.
    func pricing(forModel modelId: String) -> ModelPricing {
        let id = modelId.lowercased()
        if id.contains("opus") { return opus }
        if id.contains("haiku") { return haiku }
        if id.contains("fable") { return fable }
        return sonnet
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
