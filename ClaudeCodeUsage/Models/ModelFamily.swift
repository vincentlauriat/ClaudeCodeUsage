import SwiftUI

/// The 4 pricing tiers `PricingSettings` distinguishes between, in a fixed display/color order
/// (also the order model-mix rows are shown in, sorted highest-tier-first).
enum ModelFamily: String, CaseIterable, Identifiable {
    case opus = "Opus"
    case sonnet = "Sonnet"
    case haiku = "Haiku"
    case fable = "Fable"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .opus: Color(red: 0.29, green: 0.51, blue: 0.86)
        case .sonnet: Color(red: 0.11, green: 0.62, blue: 0.55)
        case .haiku: Color(red: 0.85, green: 0.68, blue: 0.10)
        case .fable: Color(red: 0.24, green: 0.56, blue: 0.16)
        }
    }
}

/// One family's share of estimated cost for the currently filtered usage — a row in the
/// "Model mix" panel.
struct ModelMixRow: Identifiable {
    var id: ModelFamily { family }
    let family: ModelFamily
    let costUSD: Double
}
