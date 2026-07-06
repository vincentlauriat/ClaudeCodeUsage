import SwiftUI

/// Cost/token breakdown grouped by project, agent, or skill — switchable via a segmented
/// control, sorted by estimated cost descending.
struct BreakdownView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var dimension: BreakdownDimension = .project

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BREAKDOWN")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker("", selection: $dimension) {
                    ForEach(BreakdownDimension.allCases) { dimension in
                        Text(dimension.rawValue).tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .labelsHidden()
            }

            let rows = viewModel.breakdown(for: dimension)
            if rows.isEmpty {
                Text("No usage data in this range.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    header
                    ForEach(rows) { row in
                        rowView(row)
                        if row.id != rows.last?.id {
                            Divider().overlay(Theme.panelBorder)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var header: some View {
        HStack {
            Text(dimension.rawValue.uppercased())
            Spacer()
            Text("TURNS").frame(width: 70, alignment: .trailing)
            Text("TOKENS").frame(width: 90, alignment: .trailing)
            Text("COST").frame(width: 90, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(Theme.textSecondary)
        .padding(.bottom, 8)
    }

    private func rowView(_ row: BreakdownRow) -> some View {
        HStack {
            Text(row.label)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(Formatters.compactCount(row.turnCount))
                .frame(width: 70, alignment: .trailing)
            Text(Formatters.compactCount(row.totalTokens))
                .frame(width: 90, alignment: .trailing)
            Text(Formatters.currency(row.estimatedCostUSD))
                .foregroundStyle(Theme.accentGreen)
                .frame(width: 90, alignment: .trailing)
        }
        .font(.callout)
        .foregroundStyle(Theme.textSecondary)
        .padding(.vertical, 6)
    }
}
