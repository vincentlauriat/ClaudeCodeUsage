import Foundation
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    static let autoRefreshInterval = 30

    @Published private(set) var allEvents: [UsageEvent] = []
    @Published var selectedModel: String? // nil == "All models"
    @Published var selectedRange: DateRangeFilter = .last30Days
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var secondsUntilRefresh = UsageViewModel.autoRefreshInterval

    private let scanner = TranscriptScanner()
    private var ticker: AnyCancellable?

    init() {
        ticker = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        Task { await refresh(fullRescan: false) }
    }

    var availableModels: [String] {
        Array(Set(allEvents.map(\.model))).sorted()
    }

    var filteredEvents: [UsageEvent] {
        let (start, end) = selectedRange.bounds()
        return allEvents.filter { event in
            if let selectedModel, event.model != selectedModel { return false }
            if let start, event.timestamp < start { return false }
            if let end, event.timestamp >= end { return false }
            return true
        }
    }

    var summary: UsageSummary {
        let events = filteredEvents
        var summary = UsageSummary()
        summary.turnCount = events.count
        summary.sessionCount = Set(events.map(\.sessionId)).count
        summary.inputTokens = events.reduce(0) { $0 + $1.inputTokens }
        summary.outputTokens = events.reduce(0) { $0 + $1.outputTokens }
        summary.cacheReadTokens = events.reduce(0) { $0 + $1.cacheReadTokens }
        summary.cacheCreationTokens = events.reduce(0) { $0 + $1.cacheCreationTokens }
        summary.estimatedCostUSD = PricingCalculator.estimatedCostUSD(for: events)
        return summary
    }

    var dailyUsages: [DailyUsage] {
        var byDay: [Date: DailyUsage] = [:]
        for event in filteredEvents {
            var daily = byDay[event.day] ?? DailyUsage(day: event.day)
            daily.inputTokens += event.inputTokens
            daily.outputTokens += event.outputTokens
            daily.cacheReadTokens += event.cacheReadTokens
            daily.cacheCreationTokens += event.cacheCreationTokens
            byDay[event.day] = daily
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    func rescan() {
        Task { await refresh(fullRescan: true) }
    }

    private func tick() {
        guard secondsUntilRefresh > 1 else {
            secondsUntilRefresh = Self.autoRefreshInterval
            Task { await refresh(fullRescan: false) }
            return
        }
        secondsUntilRefresh -= 1
    }

    private func refresh(fullRescan: Bool) async {
        isScanning = true
        if fullRescan {
            await scanner.reset()
        }
        let events = await scanner.scan()
        allEvents = events
        lastUpdated = Date()
        isScanning = false
        secondsUntilRefresh = Self.autoRefreshInterval
    }
}
