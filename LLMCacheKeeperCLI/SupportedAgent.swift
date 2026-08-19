import Foundation

enum SupportedAgent: String, CaseIterable {
    case claude
    case codex
    case opencode

    var displayName: String {
        switch self {
        case .claude:
            "Claude"
        case .codex:
            "Codex"
        case .opencode:
            "OpenCode"
        }
    }

    static func matching(command: String) -> SupportedAgent? {
        let normalizedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let executableName = (normalizedCommand as NSString).lastPathComponent.lowercased()
        return allCases.first { $0.rawValue == executableName }
    }
}
