import Foundation

/// One assistant turn extracted from a Claude Code transcript, with its token usage.
struct UsageEvent: Identifiable, Hashable, Codable {
    let id: String
    let sessionId: String
    let model: String
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    /// Real working directory the turn ran in (Claude Code's `cwd`), e.g.
    /// `/Users/vincent/DevApps/ClaudeTools/ClaudeCodeUsage`. Present on sub-agent turns too
    /// (inherited from the parent session), so it doubles as the "project" grouping key.
    let cwd: String
    /// Only set on turns run by a sub-agent (`isSidechain: true`); `nil` on main-session turns.
    let attributionAgent: String?
    /// Only set on turns run by a sub-agent that was itself invoked via a skill; `nil` otherwise.
    let attributionSkill: String?

    var day: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
}
