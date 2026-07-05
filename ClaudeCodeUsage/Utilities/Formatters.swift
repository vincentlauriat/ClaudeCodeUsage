import Foundation

enum Formatters {
    /// Compact K/M token formatting matching the reference dashboard (e.g. "452.9K", "3.19M").
    static func compactCount(_ value: Int) -> String {
        let v = Double(value)
        if v >= 1_000_000 {
            return String(format: "%.2fM", v / 1_000_000)
        }
        if v >= 1_000 {
            return String(format: "%.1fK", v / 1_000)
        }
        return "\(value)"
    }

    static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private static let dayAxisFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayLabel(_ date: Date) -> String {
        dayAxisFormatter.string(from: date)
    }

    private static let updatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func updatedAt(_ date: Date) -> String {
        updatedAtFormatter.string(from: date)
    }
}
