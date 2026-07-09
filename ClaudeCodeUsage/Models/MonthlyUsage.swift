import Foundation

/// Aggregate usage for one calendar month, across all recorded history.
///
/// Computed and published by `UsageViewModel` (`monthlyUsage`) but not yet consumed by any view —
/// it's groundwork for Proposition A's "Cost per month" card (see `PLAN.md`), which only needs a
/// new `View` once built, not a new data layer.
struct MonthlyUsage: Identifiable {
    var id: Date { monthStart }
    let monthStart: Date
    var estimatedCostUSD: Double = 0
}
