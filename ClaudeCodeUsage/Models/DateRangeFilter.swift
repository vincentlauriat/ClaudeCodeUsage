import Foundation

/// The date-range presets shown in the RANGE filter row.
enum DateRangeFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case prevMonth = "Prev Month"
    case last7Days = "7d"
    case last30Days = "30d"
    case last90Days = "90d"
    case all = "All"

    var id: String { rawValue }

    /// Returns the inclusive lower bound and exclusive upper bound for this range, or `nil`
    /// bounds for `.all` (no filtering).
    func bounds(now: Date = Date(), calendar: Calendar = .current) -> (start: Date?, end: Date?) {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: today)
            return (today, end)
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
            return (start, nil)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? today
            return (start, nil)
        case .prevMonth:
            guard let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start,
                  let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else {
                return (nil, nil)
            }
            return (prevMonthStart, thisMonthStart)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: today)
            return (start, nil)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today)
            return (start, nil)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -89, to: today)
            return (start, nil)
        case .all:
            return (nil, nil)
        }
    }
}
