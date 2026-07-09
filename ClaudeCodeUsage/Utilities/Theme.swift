import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let panel = Color(red: 0.09, green: 0.10, blue: 0.115)
    static let panelBorder = Color(white: 1, opacity: 0.08)
    static let textPrimary = Color(white: 0.95)
    static let textSecondary = Color(white: 0.55)
    static let accentGreen = Color(red: 0.42, green: 0.80, blue: 0.51)
    /// General "this period" emphasis accent for the comparison charts (sessions/cost trends) —
    /// distinct from `UsageSeries.input`'s blue, which is tied to token-series semantics.
    static let accentBlue = Color(red: 0.30, green: 0.55, blue: 0.88)
}

extension View {
    func panelStyle() -> some View {
        padding(20)
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.panelBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
