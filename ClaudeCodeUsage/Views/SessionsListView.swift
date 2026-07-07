import SwiftUI

/// Named sessions (from `ai-title`/`slug`) in the current filter range, most recent first. Click
/// a row to open its detail sheet.
struct SessionsListView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var selectedSession: SessionSummary?

    private static let maxRowsShown = 30

    var body: some View {
        let sessions = viewModel.sessions

        VStack(alignment: .leading, spacing: 16) {
            Text("SESSIONS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)

            if sessions.isEmpty {
                Text("No sessions in this range.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    header
                    ForEach(sessions.prefix(Self.maxRowsShown)) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            rowView(session)
                        }
                        .buttonStyle(.plain)
                        if session.id != sessions.prefix(Self.maxRowsShown).last?.id {
                            Divider().overlay(Theme.panelBorder)
                        }
                    }
                }
                if sessions.count > Self.maxRowsShown {
                    Text("Showing \(Self.maxRowsShown) of \(sessions.count) sessions — narrow the range or project filter to see others.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }

    private var header: some View {
        HStack {
            Text("TITLE")
            Spacer()
            Text("PROJECT").frame(width: 180, alignment: .leading)
            Text("STARTED").frame(width: 130, alignment: .leading)
            Text("TURNS").frame(width: 60, alignment: .trailing)
            Text("TOKENS").frame(width: 90, alignment: .trailing)
            Text("COST").frame(width: 80, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(Theme.textSecondary)
        .padding(.bottom, 8)
    }

    private func rowView(_ session: SessionSummary) -> some View {
        HStack {
            Text(session.displayName)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(Formatters.shortenPath(session.cwd))
                .frame(width: 180, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.head)
            Text(Formatters.updatedAt(session.lastSeen))
                .frame(width: 130, alignment: .leading)
            Text(Formatters.compactCount(session.turnCount))
                .frame(width: 60, alignment: .trailing)
            Text(Formatters.compactCount(session.totalTokens))
                .frame(width: 90, alignment: .trailing)
            Text(Formatters.currency(session.estimatedCostUSD))
                .foregroundStyle(Theme.accentGreen)
                .frame(width: 80, alignment: .trailing)
        }
        .font(.callout)
        .foregroundStyle(Theme.textSecondary)
        .padding(.vertical, 6)
    }
}
