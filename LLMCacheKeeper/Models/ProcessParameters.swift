import Foundation

enum ProcessStatus: String {
    case idle
    case running
    case stopped
    case failed
}

struct ProcessParameters: Hashable, Identifiable {
    let id: UUID
    let name: String
    let pid: String
    let text: String
    let interval: String
    let typingDelay: String
    let binaryPath: String
    let useSudo: Bool

    init(
        id: UUID = UUID(),
        name: String,
        pid: String,
        text: String,
        interval: String,
        typingDelay: String,
        binaryPath: String,
        useSudo: Bool
    ) {
        self.id = id
        self.name = name
        self.pid = pid
        self.text = text
        self.interval = interval
        self.typingDelay = typingDelay
        self.binaryPath = binaryPath
        self.useSudo = useSudo
    }

    var displayLabel: String {
        name.isEmpty ? "PID \(pid) — \(text.prefix(30))\(text.count > 30 ? "…" : "")" : name
    }
}
