import Foundation

struct TerminalProcess {
    let pid: Int
    let parentPID: Int
    let processGroupID: Int
    let foregroundProcessGroupID: Int
    let tty: String
    let command: String

    var isInForegroundProcessGroup: Bool {
        foregroundProcessGroupID > 0 && processGroupID == foregroundProcessGroupID
    }

    init?(psLine: Substring) {
        let fields = psLine.split(
            separator: " ",
            maxSplits: 5,
            omittingEmptySubsequences: true
        )

        guard fields.count == 6,
              let pid = Int(fields[0]),
              let parentPID = Int(fields[1]),
              let processGroupID = Int(fields[2]),
              let foregroundProcessGroupID = Int(fields[3])
        else {
            return nil
        }

        self.pid = pid
        self.parentPID = parentPID
        self.processGroupID = processGroupID
        self.foregroundProcessGroupID = foregroundProcessGroupID
        self.tty = String(fields[4])
        self.command = String(fields[5])
    }
}
