import Foundation

/// One row of the breakdown table: a group key (project / agent / skill) with its aggregate
/// usage, sorted by cost in the view model.
struct BreakdownRow: Identifiable {
    var id: String { label }
    let label: String
    let turnCount: Int
    let totalTokens: Int
    let estimatedCostUSD: Double
}

/// The grouping dimensions offered by the breakdown panel's segmented picker.
enum BreakdownDimension: String, CaseIterable, Identifiable {
    case project = "Project"
    case agent = "Agent"
    case skill = "Skill"

    var id: String { rawValue }

    /// Group key for one event under this dimension. Sub-agent attribution fields are only
    /// populated on turns actually run by a sub-agent, so main-session turns fall back to
    /// "Direct (main session)" under Agent/Skill.
    func key(for event: UsageEvent) -> String {
        switch self {
        case .project: Formatters.shortenPath(event.cwd)
        case .agent: event.attributionAgent ?? "Direct (main session)"
        case .skill: event.attributionSkill ?? "Direct (main session)"
        }
    }
}
