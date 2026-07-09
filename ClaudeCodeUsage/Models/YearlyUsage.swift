import Foundation

/// Aggregate usage for one calendar year, across all recorded history.
///
/// Computed and published by `UsageViewModel` (`yearlyUsage`) but not yet consumed by any view —
/// it's groundwork for Proposition A's "Sessions by year" card (see `PLAN.md`), which only needs
/// a new `View` once built, not a new data layer.
struct YearlyUsage: Identifiable {
    var id: Int { year }
    let year: Int
    var sessionCount: Int = 0
    var estimatedCostUSD: Double = 0
}
