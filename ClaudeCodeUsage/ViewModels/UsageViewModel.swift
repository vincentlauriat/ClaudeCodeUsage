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

    /// Fixed "today vs yesterday" / "this week vs last week" comparisons and derived signals.
    /// These ignore the RANGE filter (a fixed window is the whole point of a day/week-over-day/
    /// week comparison) but still respect MODELS/PROJECT, like everything else. `yearlyUsage`/
    /// `monthlyUsage` have no consuming view yet — see their doc comments.
    @Published private(set) var hourlyUsageYesterday: [HourlyUsage] = []
    @Published private(set) var hourlyUsageToday: [HourlyUsage] = []
    @Published private(set) var sessionsLastWeekByWeekday: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var sessionsThisWeekByWeekday: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var yearlyUsage: [YearlyUsage] = []
    @Published private(set) var monthlyUsage: [MonthlyUsage] = []
    @Published private(set) var modelMix: [ModelMixRow] = []
    @Published private(set) var insights: [Insight] = []

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

        var mixByFamily: [ModelFamily: Double] = [:]
        for event in events {
            let cost = pricingSettings.pricing(forModel: event.model).cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
            mixByFamily[pricingSettings.family(forModel: event.model), default: 0] += cost
        }
        modelMix = ModelFamily.allCases.compactMap { family in
            guard let cost = mixByFamily[family], cost > 0 else { return nil }
            return ModelMixRow(family: family, costUSD: cost)
        }

        recomputeFixedWindows(events: events)
    }

    /// The "today vs yesterday" / "this week vs last week" comparisons and the aggregates that
    /// depend only on `allEvents`/MODELS/PROJECT (not the RANGE filter). `events` is only used
    /// here for the insights that are meant to reflect the current view (unpriced models, cache
    /// hit rate) — the week-over-week cost trend intentionally uses the unranged events instead.
    private func recomputeFixedWindows(events: [UsageEvent]) {
        let unrangedEvents = allEvents.filter { event in
            if let selectedModel, event.model != selectedModel { return false }
            if let selectedProject, event.cwd != selectedProject { return false }
            return true
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        hourlyUsageToday = computeHourlyUsage(events: unrangedEvents, dayStart: todayStart, calendar: calendar)
        hourlyUsageYesterday = computeHourlyUsage(events: unrangedEvents, dayStart: yesterdayStart, calendar: calendar)

        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = calendar.timeZone
        let thisWeekStart = isoCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart
        let lastWeekStart = isoCalendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
        sessionsThisWeekByWeekday = computeWeeklySessionCounts(events: unrangedEvents, weekStart: thisWeekStart, calendar: isoCalendar)
        sessionsLastWeekByWeekday = computeWeeklySessionCounts(events: unrangedEvents, weekStart: lastWeekStart, calendar: isoCalendar)
        let thisWeekCostUSD = computeWeeklyCost(events: unrangedEvents, weekStart: thisWeekStart, calendar: isoCalendar)
        let lastWeekCostUSD = computeWeeklyCost(events: unrangedEvents, weekStart: lastWeekStart, calendar: isoCalendar)

        yearlyUsage = computeYearlyUsage(events: unrangedEvents, calendar: calendar)
        monthlyUsage = computeMonthlyUsage(events: unrangedEvents, calendar: calendar)

        insights = InsightEngine.derive(
            events: events,
            thisWeekCostUSD: thisWeekCostUSD,
            lastWeekCostUSD: lastWeekCostUSD,
            pricingSettings: pricingSettings
        )
    }

    private func computeHourlyUsage(events: [UsageEvent], dayStart: Date, calendar: Calendar) -> [HourlyUsage] {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        var buckets = (0..<24).map { HourlyUsage(hour: $0) }
        for event in events where event.timestamp >= dayStart && event.timestamp < dayEnd {
            let hour = calendar.component(.hour, from: event.timestamp)
            buckets[hour].inputTokens += event.inputTokens
            buckets[hour].outputTokens += event.outputTokens
            buckets[hour].cacheReadTokens += event.cacheReadTokens
            buckets[hour].cacheCreationTokens += event.cacheCreationTokens
            buckets[hour].estimatedCostUSD += pricingSettings.pricing(forModel: event.model).cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
        }
        return buckets
    }

    private func computeWeeklySessionCounts(events: [UsageEvent], weekStart: Date, calendar: Calendar) -> [Int] {
        (0..<7).map { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
            let sessionIds = events.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }.map(\.sessionId)
            return Set(sessionIds).count
        }
    }

    private func computeWeeklyCost(events: [UsageEvent], weekStart: Date, calendar: Calendar) -> Double {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }
        let weekEvents = events.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
        return PricingCalculator.estimatedCostUSD(for: weekEvents, pricing: pricingSettings)
    }

    private func computeYearlyUsage(events: [UsageEvent], calendar: Calendar) -> [YearlyUsage] {
        var byYear: [Int: (sessionIds: Set<String>, costUSD: Double)] = [:]
        for event in events {
            let year = calendar.component(.year, from: event.timestamp)
            var bucket = byYear[year] ?? (Set<String>(), 0)
            bucket.sessionIds.insert(event.sessionId)
            bucket.costUSD += pricingSettings.pricing(forModel: event.model).cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
            byYear[year] = bucket
        }
        return byYear.keys.sorted().map { year in
            let bucket = byYear[year]!
            return YearlyUsage(year: year, sessionCount: bucket.sessionIds.count, estimatedCostUSD: bucket.costUSD)
        }
    }

    private func computeMonthlyUsage(events: [UsageEvent], calendar: Calendar) -> [MonthlyUsage] {
        var byMonth: [Date: Double] = [:]
        for event in events {
            let components = calendar.dateComponents([.year, .month], from: event.timestamp)
            guard let monthStart = calendar.date(from: components) else { continue }
            byMonth[monthStart, default: 0] += pricingSettings.pricing(forModel: event.model).cost(
                inputTokens: event.inputTokens,
                outputTokens: event.outputTokens,
                cacheCreationTokens: event.cacheCreationTokens,
                cacheReadTokens: event.cacheReadTokens
            )
        }
        return byMonth.keys.sorted().map { MonthlyUsage(monthStart: $0, estimatedCostUSD: byMonth[$0]!) }
    }
}
