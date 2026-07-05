import SwiftUI
import Charts

struct DailyUsageChartView: View {
    let dailyUsages: [DailyUsage]
    let rangeLabel: String

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let day: Date
        let series: UsageSeries
        let value: Int
    }

    private var points: [ChartPoint] {
        dailyUsages.flatMap { day in
            UsageSeries.allCases.map { series in
                ChartPoint(day: day.day, series: series, value: series.value(from: day))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DAILY TOKEN USAGE — \(rangeLabel.uppercased())")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)

            if dailyUsages.isEmpty {
                Text("No usage data in this range.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Tokens", point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.series.rawValue))
                }
                .chartForegroundStyleScale([
                    UsageSeries.input.rawValue: UsageSeries.input.color,
                    UsageSeries.output.rawValue: UsageSeries.output.color,
                    UsageSeries.cacheRead.rawValue: UsageSeries.cacheRead.color,
                    UsageSeries.cacheCreation.rawValue: UsageSeries.cacheCreation.color,
                ])
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Theme.panelBorder)
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(Formatters.compactCount(intValue))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine().foregroundStyle(Theme.panelBorder)
                        AxisValueLabel(format: .dateTime.month().day(), centered: false)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(minHeight: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
