import SwiftUI
import AppKit

enum Theme {
    static let background = adaptive(light: (0.976, 0.976, 0.969), dark: (0.055, 0.063, 0.075))
    static let panel = adaptive(light: (0.988, 0.988, 0.984), dark: (0.09, 0.10, 0.115))
    static let panelBorder = adaptive(light: (0, 0, 0), lightAlpha: 0.10, dark: (1, 1, 1), darkAlpha: 0.08)
    static let textPrimary = adaptive(light: (0.043, 0.043, 0.043), dark: (0.95, 0.95, 0.95))
    static let textSecondary = adaptive(light: (0.322, 0.318, 0.302), dark: (0.55, 0.55, 0.55))
    static let accentGreen = adaptive(light: (0.047, 0.639, 0.047), dark: (0.42, 0.80, 0.51))
    /// General "this period" emphasis accent for the comparison charts (sessions/cost trends) —
    /// distinct from `UsageSeries.input`'s blue, which is tied to token-series semantics.
    static let accentBlue = adaptive(light: (0.165, 0.471, 0.839), dark: (0.30, 0.55, 0.88))

    /// Builds a `Color` that tracks the window's actual appearance (light/dark) at draw time,
    /// backed by a dynamic `NSColor` — so every view reading `Theme.xxx` (or another adaptive
    /// token built with this helper, e.g. `UsageSeries`/`ModelFamily`/`Insight.Level`) repaints
    /// automatically when `AppTheme` changes, with no `@Environment(\.colorScheme)` plumbing
    /// needed anywhere else.
    static func adaptive(
        light: (Double, Double, Double),
        lightAlpha: Double = 1,
        dark: (Double, Double, Double),
        darkAlpha: Double = 1
    ) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let (r, g, b) = isDark ? dark : light
            return NSColor(red: r, green: g, blue: b, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

extension View {
    func panelStyle() -> some View {
        padding(20)
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.panelBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
