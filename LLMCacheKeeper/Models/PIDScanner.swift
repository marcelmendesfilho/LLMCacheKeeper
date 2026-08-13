import Foundation

struct PIDEntry: Identifiable, Hashable {
    let pid: Int
    let tty: String
    let command: String
    let tabTitle: String

    var id: Int { pid }
}

enum PIDScanner {
    /// Runs `LLMCacheKeeperCLI -list` and parses the output into a sorted list
    /// of PIDEntry items. The CLI prints a two-line header then one row per
    /// process. Columns are fixed-width (pid 10, tty 16, command 37, title).
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
            // Skip header rows and separator
            if str.hasPrefix("PID") || str.hasPrefix("--") { continue }

            // Columns: pid(10) tty(17 = 10 + space) command(38) title(rest)
            // Use simple space-split since ps output is space-padded.
            let trimmed = str.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                .map { String($0) }
            guard parts.count >= 2 else { continue }
            guard let pid = Int(parts[0]) else { continue }
            let tty = parts[1]
            let remainder = parts.count >= 3 ? parts[2] : ""
            // Split remainder into command + tab title. The command column is
            // 37 chars wide in the CLI output; title starts after that.
            if remainder.count > 37 {
                let cmd = String(remainder.prefix(37)).trimmingCharacters(in: .whitespaces)
                let title = String(remainder.dropFirst(37)).trimmingCharacters(in: .whitespaces)
                entries.append(PIDEntry(pid: pid, tty: tty, command: cmd, tabTitle: title))
            } else {
                entries.append(PIDEntry(pid: pid, tty: tty, command: remainder, tabTitle: ""))
            }
        }
        return entries.sorted { $0.pid < $1.pid }
    }
}