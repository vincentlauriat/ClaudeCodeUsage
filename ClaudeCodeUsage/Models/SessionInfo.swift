import Foundation

/// Session-level metadata that doesn't live on every transcript line — a human-readable name
/// only appears on standalone `type: "ai-title"` lines (or the `slug` field on a few line
/// types), so it's collected separately from `UsageEvent` while scanning every line, not just
/// assistant turns.
struct SessionInfo: Codable {
    var title: String?
    var slug: String?
    var cwd: String?

    /// Best available human-readable label for this session.
    func displayName(fallback sessionId: String) -> String {
        title ?? slug ?? String(sessionId.prefix(8))
    }
}
