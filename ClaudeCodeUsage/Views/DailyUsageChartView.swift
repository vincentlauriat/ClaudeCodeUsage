import SwiftUI
import Charts

/// Reproduces the reference dashboard's original two-axis look: Cache Read/Creation are scaled
/// against a left "millions" axis, Input/Output against a right "hundreds of thousands" axis,
/// both stacked into the same daily bar. This is a deliberate visual replica, not a
/// mathematically consistent chart — the two groups are each normalized against their own
/// per-range max, so a bar's total height doesn't correspond to any single real total (matching
/// the original capture, which has the same property).
struct DailyUsageChartView: View {
    let dailyUsages: [DailyUsage]
    let rangeLabel: String

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let day: Date
        let series: UsageSeries
        /// Value as a fraction (0...1) of this series' own axis-group max for the range.
        let normalizedValue: Double
    }

    /// Fixed tick positions on the shared 0...1 plotting scale — each is independently labeled
    /// against the cache axis (leading) and the input/output axis (trailing).
    private static let axisFractions: [Double] = [0, 0.25, 0.5, 0.75, 1.0]

    private var cacheMax: Double {
        max(dailyUsages.map { Double($0.cacheReadTokens + $0.cacheCreationTokens) }.max() ?? 1, 1)
    }

    private var ioMax: Double {
        max(dailyUsages.map { Double($0.inputTokens + $0.outputTokens) }.max() ?? 1, 1)
    }

    private var points: [ChartPoint] {
        let cacheMax = cacheMax
        let ioMax = ioMax
        return dailyUsages.flatMap { day in
            UsageSeries.allCases.map { series in
                let raw = Double(series.value(from: day))
                let denominator = series.isCacheAxis ? cacheMax : ioMax
                return ChartPoint(day: day.day, series: series, normalizedValue: raw / denominator)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DAILY TOKEN USAGE — \(rangeLabel.uppercased())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !dailyUsages.isEmpty {
                    Text("CACHE")
                        .font(.caption2)
                        .foregroundStyle(UsageSeries.cacheRead.color)
                    Text("·")
                        .foregroundStyle(Theme.textSecondary)
                    Text("INPUT / OUTPUT")
                        .font(.caption2)
                        .foregroundStyle(UsageSeries.input.color)
                }
            }

            if dailyUsages.isEmpty {
                Text("No usage data in this range.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
            } else {
                let cacheMax = cacheMax
                let ioMax = ioMax
                Chart(points) { point in
                    BarMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Tokens", point.normalizedValue)
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
                    AxisMarks(position: .leading, values: Self.axisFractions) { value in
                        AxisGridLine().foregroundStyle(Theme.panelBorder)
                        AxisValueLabel {
                            if let fraction = value.as(Double.self) {
                                Text(Formatters.compactCount(Int(fraction * cacheMax)))
                                    .foregroundStyle(UsageSeries.cacheRead.color)
                            }
                        }
                    }
                    AxisMarks(position: .trailing, values: Self.axisFractions) { value in
                        AxisValueLabel {
                            if let fraction = value.as(Double.self) {
                                Text(Formatters.compactCount(Int(fraction * ioMax)))
                                    .foregroundStyle(UsageSeries.input.color)
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
