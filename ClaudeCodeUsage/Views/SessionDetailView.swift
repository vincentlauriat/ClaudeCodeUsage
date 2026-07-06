import SwiftUI

/// Detail sheet for one session: identity, time range, and token/cost totals.
struct SessionDetailView: View {
    let session: SessionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(session.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Done", action: dismiss.callAsFunction)
            }

            Text(Formatters.shortenPath(session.cwd))
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)

            Text("\(Formatters.updatedAt(session.firstSeen)) → \(Formatters.updatedAt(session.lastSeen))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Divider().overlay(Theme.panelBorder)

            HStack(spacing: 12) {
                StatCardView(title: "Turns", value: "\(session.turnCount)", subtitle: session.modelsUsed.joined(separator: ", "))
                StatCardView(title: "Input", value: Formatters.compactCount(session.inputTokens), subtitle: "tokens")
                StatCardView(title: "Output", value: Formatters.compactCount(session.outputTokens), subtitle: "tokens")
                StatCardView(title: "Cache Read", value: Formatters.compactCount(session.cacheReadTokens), subtitle: "tokens")
                StatCardView(title: "Cache Creation", value: Formatters.compactCount(session.cacheCreationTokens), subtitle: "tokens")
                StatCardView(title: "Est. Cost", value: Formatters.currency(session.estimatedCostUSD), subtitle: "approx.", valueColor: Theme.accentGreen)
            }

            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .frame(minWidth: 720, minHeight: 260)
    }
}
