import SwiftUI
import Charts

/// "This week vs last week" session-count trend, one point per weekday — last week is context
/// (gray), this week is the emphasis series (accent blue). Independent of the RANGE filter: a
/// week-over-week comparison against an arbitrary range wouldn't mean anything.
struct SessionsPerWeekChartView: View {
    let lastWeek: [Int] // 7 values, Monday...Sunday
    let thisWeek: [Int] // 7 values, Monday...Sunday

    private static let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private struct Point: Identifiable {
        let weekday: String
        let index: Int
        let value: Int
        let series: String
        var id: String { "\(series)-\(index)" }
    }

    private var points: [Point] {
        Self.weekdayLabels.indices.flatMap { i in
            [
                Point(weekday: Self.weekdayLabels[i], index: i, value: lastWeek[i], series: "Last week"),
                Point(weekday: Self.weekdayLabels[i], index: i, value: thisWeek[i], series: "This week"),
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Chart(points) { point in
                LineMark(
                    x: .value("Day", point.weekday),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale([
                "Last week": Theme.textSecondary,
                "This week": Theme.accentBlue,
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.panelBorder)
                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel().foregroundStyle(Theme.textSecondary) }
            }
            .frame(minHeight: 160)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var header: some View {
        HStack {
            Text("SESSIONS PER WEEK")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("LAST WEEK")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text("·")
                .foregroundStyle(Theme.textSecondary)
            Text("THIS WEEK")
                .font(.caption2)
                .foregroundStyle(Theme.accentBlue)
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST WEEK").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text("\(lastWeek.reduce(0, +))")
                    .font(.title3).fontWeight(.semibold).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("THIS WEEK").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text("\(thisWeek.reduce(0, +))")
                    .font(.title3).fontWeight(.semibold).foregroundStyle(Theme.accentBlue)
            }
        }
    }
}
