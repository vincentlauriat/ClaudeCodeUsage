import SwiftUI

/// Estimated cost split by pricing family (Opus/Sonnet/Haiku/Fable) for the currently filtered
/// usage, as a single horizontal stacked bar — a part-to-whole view, not a trend, so a stacked
/// bar rather than a pie/donut.
struct ModelMixView: View {
    let rows: [ModelMixRow]

    private var total: Double { rows.reduce(0) { $0 + $1.costUSD } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODEL MIX")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            if rows.isEmpty || total <= 0 {
                Text("No usage data in this range.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                stackedBar
                legend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(rows) { row in
                    row.family.color
                        .frame(width: geo.size.width * (row.costUSD / total))
                }
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(row.family.color)
                        .frame(width: 9, height: 9)
                    Text("\(row.family.rawValue) · \(Int((row.costUSD / total * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(Formatters.currency(row.costUSD))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }
}
