import Foundation

/// Incrementally scans Claude Code's JSONL transcripts under `~/.claude/projects/**` and
/// extracts `UsageEvent`s from assistant turns.
///
/// Transcripts are append-only, so each scan only reads the bytes appended since the last scan
/// of a given file (tracked by byte offset + mtime). Call `reset()` to force a full re-read
/// (used by the "Rescan" button).
actor TranscriptScanner {
    private struct FileState {
        var offset: UInt64
        var mtime: Date
        var events: [UsageEvent]
    }

    private var fileStates: [String: FileState] = [:]

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
    func reset() {
        fileStates.removeAll()
    }

    /// Scans every `.jsonl` transcript and returns the full accumulated set of usage events.
    func scan() -> [UsageEvent] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        if let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                scanFile(at: fileURL)
            }
        }

        return fileStates.values.flatMap(\.events)
    }

    private func scanFile(at url: URL) {
        let path = url.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = (attrs[.size] as? NSNumber)?.uint64Value else { return }

        if let existing = fileStates[path], existing.mtime == mtime, existing.offset == size {
            return // unchanged since last scan
        }

        var startOffset: UInt64 = 0
        var priorEvents: [UsageEvent] = []
        if let existing = fileStates[path], size >= existing.offset {
            startOffset = existing.offset
            priorEvents = existing.events
        }
        // Otherwise the file shrank/was replaced (unexpected for append-only transcripts) —
        // fall back to a full re-read from the start.

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: startOffset)

        guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else {
            fileStates[path] = FileState(offset: startOffset, mtime: mtime, events: priorEvents)
            return
        }

        guard let lastNewline = chunk.lastIndex(of: UInt8(ascii: "\n")) else {
            // No complete line yet in this chunk (mid-write) — retry from the same offset later.
            fileStates[path] = FileState(offset: startOffset, mtime: mtime, events: priorEvents)
            return
        }

        let completeData = chunk[chunk.startIndex...lastNewline]
        let newOffset = startOffset + UInt64(completeData.count)
        let text = String(decoding: completeData, as: UTF8.self)

        var newEvents: [UsageEvent] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let event = Self.parseLine(line) {
                newEvents.append(event)
            }
        }

        fileStates[path] = FileState(offset: newOffset, mtime: mtime, events: priorEvents + newEvents)
    }

    private static func parseLine(_ line: Substring) -> UsageEvent? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["type"] as? String) == "assistant",
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String,
              let sessionId = (obj["sessionId"] as? String) ?? (obj["session_id"] as? String),
              let timestampString = obj["timestamp"] as? String,
              let timestamp = date(from: timestampString)
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
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0
        )
    }

    private static func date(from string: String) -> Date? {
        isoFormatterWithFraction.date(from: string) ?? isoFormatter.date(from: string)
    }
}
