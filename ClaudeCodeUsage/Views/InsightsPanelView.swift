import SwiftUI

/// Automatically-derived signals about the currently filtered usage — cost trend, pricing gaps,
/// cache efficiency. See `InsightEngine` for how each row is derived.
struct InsightsPanelView: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS & ALERTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(insights) { insight in
                    row(insight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func row(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(insight.level.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(insight.level.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(insight.level.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(insight.text)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
