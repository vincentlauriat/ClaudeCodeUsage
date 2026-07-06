import Foundation

/// Incrementally scans Claude Code's JSONL transcripts under `~/.claude/projects/**` and
/// extracts `UsageEvent`s from assistant turns.
///
/// Transcripts are append-only, so each scan only reads the bytes appended since the last scan
/// of a given file (tracked by byte offset + mtime). Call `reset()` to force a full re-read
/// (used by the "Rescan" button).
actor TranscriptScanner {
    /// Everything a scan produces: the flat event list (for stats/charts/breakdowns) plus the
    /// session-level metadata collected along the way (for the sessions list).
    struct ScanResult {
        let events: [UsageEvent]
        let sessionInfo: [String: SessionInfo]
    }

    private struct FileState: Codable {
        var offset: UInt64
        var mtime: Date
        var events: [UsageEvent]
    }

    /// Everything persisted to disk between launches, so a relaunch doesn't have to re-read every
    /// transcript from byte zero.
    private struct PersistedCache: Codable {
        var fileStates: [String: FileState]
        var sessionInfo: [String: SessionInfo]
    }

    private var fileStates: [String: FileState] = [:]
    /// Keyed by sessionId. `ai-title`/`slug`/`cwd` don't appear on every line (unlike the fields
    /// on `UsageEvent`), so they're accumulated separately while scanning every line type, not
    /// just assistant turns.
    private var sessionInfoBySessionId: [String: SessionInfo] = [:]
    private var didLoadPersistedCache = false

    private static var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("ClaudeCodeUsage", isDirectory: true)
    }

    private static var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent("scan-cache.json")
    }

    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Clears all cached offsets, forcing a full re-read of every transcript on the next scan.
    /// Also drops the on-disk cache so a relaunch after "Rescan" doesn't reload stale data.
    func reset() {
        fileStates.removeAll()
        sessionInfoBySessionId.removeAll()
        try? FileManager.default.removeItem(at: Self.cacheFileURL)
    }

    /// Scans every `.jsonl` transcript and returns the full accumulated set of usage events plus
    /// per-session metadata (title/slug/project).
    func scan() -> ScanResult {
        loadPersistedCacheIfNeeded()

        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        var didChange = false
        if let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                if scanFile(at: fileURL) {
                    didChange = true
                }
            }
        }

        if didChange {
            persistCache()
        }

        return ScanResult(
            events: fileStates.values.flatMap(\.events),
            sessionInfo: sessionInfoBySessionId
        )
    }

    /// Loads the on-disk cache (if any) once per process, so the very first scan after launch
    /// only has to read bytes appended since the app was last quit.
    private func loadPersistedCacheIfNeeded() {
        guard !didLoadPersistedCache else { return }
        didLoadPersistedCache = true
        guard let data = try? Data(contentsOf: Self.cacheFileURL),
              let persisted = try? JSONDecoder().decode(PersistedCache.self, from: data)
        else { return }
        fileStates = persisted.fileStates
        sessionInfoBySessionId = persisted.sessionInfo
    }

    private func persistCache() {
        let payload = PersistedCache(fileStates: fileStates, sessionInfo: sessionInfoBySessionId)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheFileURL, options: .atomic)
    }

    /// Returns whether this file's cached state actually changed (new bytes read, or its mtime
    /// moved) — callers use this to skip writing the persisted cache back to disk when nothing
    /// happened, which is the common case on a 30s auto-refresh with no new Claude Code activity.
    @discardableResult
    private func scanFile(at url: URL) -> Bool {
        let path = url.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = (attrs[.size] as? NSNumber)?.uint64Value else { return false }

        if let existing = fileStates[path], existing.mtime == mtime, existing.offset == size {
            return false // unchanged since last scan
        }

        var startOffset: UInt64 = 0
        var priorEvents: [UsageEvent] = []
        if let existing = fileStates[path], size >= existing.offset {
            startOffset = existing.offset
            priorEvents = existing.events
        }
        // Otherwise the file shrank/was replaced (unexpected for append-only transcripts) —
        // fall back to a full re-read from the start.

        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        try? handle.seek(toOffset: startOffset)

        guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else {
            fileStates[path] = FileState(offset: startOffset, mtime: mtime, events: priorEvents)
            return true
        }

        guard let lastNewline = chunk.lastIndex(of: UInt8(ascii: "\n")) else {
            // No complete line yet in this chunk (mid-write) — retry from the same offset later.
            fileStates[path] = FileState(offset: startOffset, mtime: mtime, events: priorEvents)
            return true
        }

        let completeData = chunk[chunk.startIndex...lastNewline]
        let newOffset = startOffset + UInt64(completeData.count)
        let text = String(decoding: completeData, as: UTF8.self)

        var newEvents: [UsageEvent] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let obj = Self.parseJSON(line) else { continue }

            if let event = Self.parseEvent(from: obj) {
                newEvents.append(event)
            }
            if let sessionId = (obj["sessionId"] as? String) ?? (obj["session_id"] as? String) {
                updateSessionInfo(sessionId: sessionId, obj: obj)
            }
        }

        fileStates[path] = FileState(offset: newOffset, mtime: mtime, events: priorEvents + newEvents)
        return true
    }

    /// Merges any of `title`/`slug`/`cwd` found on this line into that session's accumulated
    /// info. Called for every line type (not just assistant turns), since a human-readable name
    /// only ever appears on a standalone `type: "ai-title"` line.
    private func updateSessionInfo(sessionId: String, obj: [String: Any]) {
        var info = sessionInfoBySessionId[sessionId] ?? SessionInfo()
        if (obj["type"] as? String) == "ai-title", let aiTitle = obj["aiTitle"] as? String {
            info.title = aiTitle
        }
        if let slug = obj["slug"] as? String {
            info.slug = slug
        }
        if let cwd = obj["cwd"] as? String {
            info.cwd = cwd
        }
        sessionInfoBySessionId[sessionId] = info
    }

    private static func parseJSON(_ line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseEvent(from obj: [String: Any]) -> UsageEvent? {
        guard (obj["type"] as? String) == "assistant",
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String,
              let sessionId = (obj["sessionId"] as? String) ?? (obj["session_id"] as? String),
              let timestampString = obj["timestamp"] as? String,
              let timestamp = date(from: timestampString),
              let cwd = obj["cwd"] as? String
        else { return nil }

        let id = (obj["uuid"] as? String) ?? (message["id"] as? String) ?? UUID().uuidString

        return UsageEvent(
            id: id,
            sessionId: sessionId,
            model: model,
            timestamp: timestamp,
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0,
            cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
            cwd: cwd,
            attributionAgent: obj["attributionAgent"] as? String,
            attributionSkill: obj["attributionSkill"] as? String
        )
    }

    private static func date(from string: String) -> Date? {
        isoFormatterWithFraction.date(from: string) ?? isoFormatter.date(from: string)
    }
}
