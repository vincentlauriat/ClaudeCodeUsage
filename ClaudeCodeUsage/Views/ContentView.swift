import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UsageViewModel()

    private let statColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    private let cardColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel)
            Divider().overlay(Theme.panelBorder)
            FilterBarView(viewModel: viewModel)
            Divider().overlay(Theme.panelBorder)

            ScrollView {
                VStack(spacing: 16) {
                    statGrid
                    LazyVGrid(columns: cardColumns, spacing: 16) {
                        SessionsPerWeekChartView(
                            lastWeek: viewModel.sessionsLastWeekByWeekday,
                            thisWeek: viewModel.sessionsThisWeekByWeekday
                        )
                        CostPerHourChartView(
                            yesterday: viewModel.hourlyUsageYesterday,
                            today: viewModel.hourlyUsageToday
                        )
                        InsightsPanelView(insights: viewModel.insights)
                        ModelMixView(rows: viewModel.modelMix)
                    }
                    DailyUsageChartView(
                        dailyUsages: viewModel.dailyUsages,
                        rangeLabel: viewModel.selectedRange.rawValue
                    )
                    BreakdownView(viewModel: viewModel)
                    SessionsListView(viewModel: viewModel)
                }
                .padding(24)
            }
        }
        .background(Theme.background)
        .frame(minWidth: 980, minHeight: 1100)
    }

    private var statGrid: some View {
        let summary = viewModel.summary
        return LazyVGrid(columns: statColumns, spacing: 12) {
            StatCardView(
                title: "Sessions",
                value: "\(summary.sessionCount)",
                subtitle: subtitle
            )
            StatCardView(
                title: "Turns",
                value: Formatters.compactCount(summary.turnCount),
                subtitle: subtitle
            )
            StatCardView(
                title: "Input Tokens",
                value: Formatters.compactCount(summary.inputTokens),
                subtitle: subtitle
            )
            StatCardView(
                title: "Output Tokens",
                value: Formatters.compactCount(summary.outputTokens),
                subtitle: subtitle
            )
            StatCardView(
                title: "Cache Read",
                value: Formatters.compactCount(summary.cacheReadTokens),
                subtitle: "from prompt cache"
            )
            StatCardView(
                title: "Cache Creation",
                value: Formatters.compactCount(summary.cacheCreationTokens),
                subtitle: "writes to prompt cache"
            )
            StatCardView(
                title: "Est. Cost",
                value: Formatters.currency(summary.estimatedCostUSD),
                subtitle: "API pricing, approx.",
                valueColor: Theme.accentGreen
            )
        }
    }

    private var subtitle: String {
        viewModel.selectedRange == .all ? "all time" : viewModel.selectedRange.rawValue.lowercased()
    }
}

#Preview {
    ContentView()
}
