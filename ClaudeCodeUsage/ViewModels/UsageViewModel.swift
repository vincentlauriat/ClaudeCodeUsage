import Foundation
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    static let autoRefreshInterval = 30

    @Published private(set) var allEvents: [UsageEvent] = [] {
        didSet { recomputeAll() }
    }
    @Published private(set) var sessionInfo: [String: SessionInfo] = [:] {
        didSet { recomputeAll() }
    }
    @Published var selectedModel: String? { // nil == "All models"
        didSet { recomputeFiltered() }
    }
    @Published var selectedProject: String? { // nil == "All projects"; holds a raw `cwd` value
        didSet { recomputeFiltered() }
    }
    @Published var selectedRange: DateRangeFilter = .last30Days {
        didSet { recomputeFiltered() }
    }
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var secondsUntilRefresh = UsageViewModel.autoRefreshInterval
    @Published var pricingSettings: PricingSettings = PricingSettings.loadFromUserDefaults() {
        didSet {
            pricingSettings.saveToUserDefaults()
            recomputeFiltered()
        }
    }

    /// Everything below is derived from `allEvents`/`sessionInfo`/the filters/pricing above.
    /// They're recomputed only when one of those actually changes (see `recomputeAll`/
    /// `recomputeFiltered`), not on every SwiftUI re-render — the 1s auto-refresh countdown
    /// lives on this same object, and without caching, every tick used to force a full
    /// re-filter/re-group/re-sort of the entire event set for every panel, which is what caused
    /// the frequent UI hangs.
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var availableProjects: [String] = []
    @Published private(set) var filteredEvents: [UsageEvent] = []
    @Published private(set) var summary = UsageSummary()
    @Published private(set) var dailyUsages: [DailyUsage] = []
    @Published private(set) var sessions: [SessionSummary] = []
    private var breakdownCache: [BreakdownDimension: [BreakdownRow]] = [:]

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

    /// Sorted (by cost descending) aggregate rows for the breakdown panel's currently selected
    /// dimension. Cached per-dimension until the underlying filtered data changes.
    func breakdown(for dimension: BreakdownDimension) -> [BreakdownRow] {
        if let cached = breakdownCache[dimension] { return cached }

        // Accumulates cost incrementally per key rather than collecting each key's events into an
        // array to cost afterwards: a growing `[UsageEvent]` inside a dictionary value forces a
        // full array copy on every append (the dictionary's stored copy and the local `var`
        // holding it are briefly both alive, so copy-on-write can't reuse the buffer) — an O(n²)
        // blowup once one key (e.g. "Direct (main session)" for Agent/Skill) absorbs most events.
        var byKey: [String: (turnCount: Int, tokens: Int, costUSD: Double)] = [:]
        for event in filteredEvents {
            let key = dimension.key(for: event)
            let cost = pricingSettings.pricing(forModel: event.model).cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
            var bucket = byKey[key] ?? (0, 0, 0)
            bucket.turnCount += 1
            bucket.tokens += event.inputTokens + event.outputTokens + event.cacheCreationTokens + event.cacheReadTokens
            bucket.costUSD += cost
            byKey[key] = bucket
        }
        let rows = byKey.map { key, bucket in
            BreakdownRow(
                label: key,
                turnCount: bucket.turnCount,
                totalTokens: bucket.tokens,
                estimatedCostUSD: bucket.costUSD
            )
        }.sorted { $0.estimatedCostUSD > $1.estimatedCostUSD }

        breakdownCache[dimension] = rows
        return rows
    }

    func resetPricingToDefaults() {
        pricingSettings = .default
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

    /// Called when `allEvents`/`sessionInfo` change (new scan results): refreshes the filter
    /// pickers' option lists (which only depend on the full event set) and the filtered
    /// aggregates below them.
    private func recomputeAll() {
        availableModels = Array(Set(allEvents.map(\.model))).sorted()
        availableProjects = Array(Set(allEvents.map(\.cwd))).sorted()
        recomputeFiltered()
    }

    /// Called whenever anything the filtered aggregates depend on changes: the event set, the
    /// three filters, or pricing (which feeds every cost figure).
    private func recomputeFiltered() {
        let (start, end) = selectedRange.bounds()
        let events = allEvents.filter { event in
            if let selectedModel, event.model != selectedModel { return false }
            if let selectedProject, event.cwd != selectedProject { return false }
            if let start, event.timestamp < start { return false }
            if let end, event.timestamp >= end { return false }
            return true
        }
        filteredEvents = events

        var newSummary = UsageSummary()
        newSummary.turnCount = events.count
        newSummary.sessionCount = Set(events.map(\.sessionId)).count
        newSummary.inputTokens = events.reduce(0) { $0 + $1.inputTokens }
        newSummary.outputTokens = events.reduce(0) { $0 + $1.outputTokens }
        newSummary.cacheReadTokens = events.reduce(0) { $0 + $1.cacheReadTokens }
        newSummary.cacheCreationTokens = events.reduce(0) { $0 + $1.cacheCreationTokens }
        newSummary.estimatedCostUSD = PricingCalculator.estimatedCostUSD(for: events, pricing: pricingSettings)
        summary = newSummary

        var byDay: [Date: DailyUsage] = [:]
        for event in events {
            var daily = byDay[event.day] ?? DailyUsage(day: event.day)
            daily.inputTokens += event.inputTokens
            daily.outputTokens += event.outputTokens
            daily.cacheReadTokens += event.cacheReadTokens
            daily.cacheCreationTokens += event.cacheCreationTokens
            byDay[event.day] = daily
        }
        dailyUsages = byDay.values.sorted { $0.day < $1.day }

        var eventsBySession: [String: [UsageEvent]] = [:]
        for event in events {
            eventsBySession[event.sessionId, default: []].append(event)
        }
        sessions = eventsBySession.compactMap { sessionId, sessionEvents in
            SessionSummary(sessionId: sessionId, events: sessionEvents, info: sessionInfo[sessionId], pricing: pricingSettings)
        }.sorted { $0.lastSeen > $1.lastSeen }

        breakdownCache.removeAll()
    }
}
