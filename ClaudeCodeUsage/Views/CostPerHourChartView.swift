import SwiftUI
import Charts

/// "Yesterday vs today, by hour" cost bullet chart: yesterday is a full-width context bar,
/// today overlays as a narrower emphasis bar on the same hour slot, with a dashed rule marking
/// the current hour. Two independently-colored `BarMark` series drawn without a shared
/// `foregroundStyle(by:)` key so Swift Charts overlays them instead of dodging them side by side.
struct CostPerHourChartView: View {
    let yesterday: [HourlyUsage] // 24 entries, hour 0...23
    let today: [HourlyUsage] // 24 entries, hour 0...23

    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Chart {
                // `.fixed(_:)`, not `.ratio(_:)`: with a plain `Int` x-value (no `.day`-style unit
                // to band against), Swift Charts silently fails to draw anything for a
                // ratio-sized bar — it needs an absolute width.
                ForEach(yesterday) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Cost", bucket.estimatedCostUSD),
                        width: .fixed(12)
                    )
                    .foregroundStyle(Theme.textSecondary.opacity(0.35))
                }
                ForEach(today) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Cost", bucket.estimatedCostUSD),
                        width: .fixed(6)
                    )
                    .foregroundStyle(Theme.accentBlue)
                }
                RuleMark(x: .value("Hour", currentHour))
                    .foregroundStyle(Theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .center) {
                        Text("now").font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.panelBorder)
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(Self.hourLabel(hour)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.panelBorder)
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(Formatters.currency(cost)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(minHeight: 160)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var header: some View {
        HStack {
            Text("COST PER HOUR")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("YESTERDAY")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text("·")
                .foregroundStyle(Theme.textSecondary)
            Text("TODAY")
                .font(.caption2)
                .foregroundStyle(Theme.accentBlue)
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YESTERDAY").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text(Formatters.currency(yesterday.reduce(0) { $0 + $1.estimatedCostUSD }))
                    .font(.title3).fontWeight(.semibold).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TODAY SO FAR").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text(Formatters.currency(today.reduce(0) { $0 + $1.estimatedCostUSD }))
                    .font(.title3).fontWeight(.semibold).foregroundStyle(Theme.accentBlue)
            }
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12a"
        case 12: "12p"
        case ..<12: "\(hour)a"
        default: "\(hour - 12)p"
        }
    }
}
