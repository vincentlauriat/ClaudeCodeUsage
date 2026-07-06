import XCTest
@testable import ClaudeCodeUsage

final class PricingCalculatorTests: XCTestCase {
    func testSonnetCostMatchesExpectedRatios() {
        let pricing = PricingSettings.default.pricing(forModel: "claude-sonnet-5")
        let cost = pricing.cost(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            cacheCreationTokens: 0,
            cacheReadTokens: 0
        )
        XCTAssertEqual(cost, pricing.inputPerMTok + pricing.outputPerMTok, accuracy: 0.0001)
    }

    func testUnknownModelFallsBackToSonnetTier() {
        let pricing = PricingSettings.default.pricing(forModel: "some-future-model")
        XCTAssertEqual(pricing.inputPerMTok, PricingSettings.default.sonnet.inputPerMTok)
    }
}
