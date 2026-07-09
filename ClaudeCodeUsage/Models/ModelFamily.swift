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
        case .opus: Theme.adaptive(light: (0.145, 0.365, 0.72), dark: (0.29, 0.51, 0.86))
        case .sonnet: Theme.adaptive(light: (0.06, 0.45, 0.40), dark: (0.11, 0.62, 0.55))
        case .haiku: Theme.adaptive(light: (0.65, 0.48, 0.03), dark: (0.85, 0.68, 0.10))
        case .fable: Theme.adaptive(light: (0.15, 0.42, 0.09), dark: (0.24, 0.56, 0.16))
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
