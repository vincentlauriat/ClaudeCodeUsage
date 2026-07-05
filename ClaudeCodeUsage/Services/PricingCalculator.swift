import Foundation

/// Computes the estimated USD cost of a set of usage events, applying each event's own model
/// pricing tier (see `ModelPricing`).
enum PricingCalculator {
    static func estimatedCostUSD(for events: some Sequence<UsageEvent>) -> Double {
        events.reduce(0) { total, event in
            let pricing = ModelPricing.forModel(event.model)
            return total + pricing.cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
        }
    }
}
