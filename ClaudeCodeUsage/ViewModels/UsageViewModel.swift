import Foundation
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    static let autoRefreshInterval = 30

    @Published private(set) var allEvents: [UsageEvent] = []
    @Published private(set) var sessionInfo: [String: SessionInfo] = [:]
    @Published var selectedModel: String? // nil == "All models"
    @Published var selectedProject: String? // nil == "All projects"; holds a raw `cwd` value
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

    var availableProjects: [String] {
        Array(Set(allEvents.map(\.cwd))).sorted()
    }

    var filteredEvents: [UsageEvent] {
        let (start, end) = selectedRange.bounds()
        return allEvents.filter { event in
            if let selectedModel, event.model != selectedModel { return false }
            if let selectedProject, event.cwd != selectedProject { return false }
            if let start, event.timestamp < start { return false }
            if let end, event.timestamp >= end { return false }
            return true
        }
    }

    /// Sorted (by cost descending) aggregate rows for the breakdown panel's currently selected
    /// dimension.
    func breakdown(for dimension: BreakdownDimension) -> [BreakdownRow] {
        var byKey: [String: (turnCount: Int, tokens: Int, events: [UsageEvent])] = [:]
        for event in filteredEvents {
            let key = dimension.key(for: event)
            var bucket = byKey[key] ?? (0, 0, [])
            bucket.turnCount += 1
            bucket.tokens += event.inputTokens + event.outputTokens + event.cacheCreationTokens + event.cacheReadTokens
            bucket.events.append(event)
            byKey[key] = bucket
        }
        return byKey.map { key, bucket in
            BreakdownRow(
                label: key,
                turnCount: bucket.turnCount,
                totalTokens: bucket.tokens,
                estimatedCostUSD: PricingCalculator.estimatedCostUSD(for: bucket.events)
            )
        }.sorted { $0.estimatedCostUSD > $1.estimatedCostUSD }
    }

    /// Per-session aggregates for the currently filtered events, most recently active first.
    var sessions: [SessionSummary] {
        var eventsBySession: [String: [UsageEvent]] = [:]
        for event in filteredEvents {
            eventsBySession[event.sessionId, default: []].append(event)
        }
        return eventsBySession.compactMap { sessionId, events in
            SessionSummary(sessionId: sessionId, events: events, info: sessionInfo[sessionId])
        }.sorted { $0.lastSeen > $1.lastSeen }
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
        let result = await scanner.scan()
        allEvents = result.events
        sessionInfo = result.sessionInfo
        lastUpdated = Date()
        isScanning = false
        secondsUntilRefresh = Self.autoRefreshInterval
    }
}
