import Foundation

struct PIDEntry: Identifiable, Hashable {
    let pid: Int
    let tty: String
    let command: String
    let tabTitle: String

    var id: String { tty }
}

enum PIDScanner {
    /// Runs `LLMCacheKeeperCLI -list` and parses the output into a sorted list
    /// of PIDEntry items. The CLI returns one tab-separated row per valid TTY.
    static func scan(binaryPath: String) async -> [PIDEntry] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binaryPath)
        task.arguments = ["-list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try task.run()
        } catch {
            return []
        }

        // Read concurrently to avoid pipe deadlock.
        let handle = pipe.fileHandleForReading
        var outData = Data()
        let readQ = DispatchQueue(label: "pidscanner.read")
        readQ.async { outData = handle.readDataToEndOfFile() }
        task.waitUntilExit()
        readQ.sync { }

        guard task.terminationStatus == 0,
              let raw = String(data: outData, encoding: .utf8) else {
            return []
        }

        return parse(raw)
    }

    private static func parse(_ output: String) -> [PIDEntry] {
        var entries: [PIDEntry] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let str = String(line)
            if str.hasPrefix("PID\t") { continue }

            let parts = str.split(
                separator: "\t",
                maxSplits: 3,
                omittingEmptySubsequences: false
            )
                .map { String($0) }

            guard parts.count == 4 else { continue }
            guard let pid = Int(parts[0]) else { continue }
            entries.append(
                PIDEntry(
                    pid: pid,
                    tty: parts[1],
                    command: parts[2],
                    tabTitle: parts[3]
                )
            )
        }
        return entries
    }
}
