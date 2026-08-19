import Foundation
import Darwin

// MARK: - ListCommand (-list)
/// Lists one valid agent session per leaf TTY. A session is valid when its
/// foreground process group contains a supported LLM agent. This deliberately
/// excludes idle shells, helper processes, and outer multiplexer terminals.
enum ListCommand {
    static func run() {
        fflush(stdout)

        let sessions = TerminalSessionDiscovery.discover()
        guard !sessions.isEmpty else {
            print("No supported agent session found.")
            fflush(stdout)
            return
        }

        let ttyTitles = fetchTerminalTabTitles(timeoutSeconds: 8)

        print("PID\tTTY\tAGENT\tTAB")
        for session in sessions {
            let ttyPath = session.tty.hasPrefix("/dev/") ? session.tty : "/dev/\(session.tty)"
            let title = ttyTitles[ttyPath] ?? ""
            print("\(session.pid)\t\(session.tty)\t\(session.agent.displayName)\t\(title)")
        }
        print("")
        print("\(sessions.count) valid agent session(s) listed. Use the desired PID in: \(exeName()) <pid> \"text\" <seconds>")
        fflush(stdout)
    }

    // MARK: - AppleScript: Terminal tab titles (best-effort, with timeout)

    /// Returns a dictionary [ttyPath: tabTitle] by querying Terminal.app.
    /// Uses an AppleScript `repeat` to produce clean "tty\\t title\\n" pairs
    /// (avoids nested-list coercion from `every tab of every window`).
    /// Applies a hard timeout: if osascript doesn't finish within
    /// `timeoutSeconds`, the process is killed and an empty dictionary is
    /// returned.
    private static func fetchTerminalTabTitles(timeoutSeconds: Int) -> [String: String] {
        let script = """
        set output to ""
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    set output to output & (tty of t) & "\\t" & (custom title of t) & "\\n"
                end repeat
            end repeat
        end tell
        return output
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do { try process.run() } catch { return [:] }

        // Read concurrently (avoids deadlock if output grows beyond the pipe).
        let handle = pipe.fileHandleForReading
        var outData = Data()
        let readQ = DispatchQueue(label: "list.as.read")
        readQ.async { outData = handle.readDataToEndOfFile() }

        // Wait with timeout.
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while process.isRunning && Date() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
        readQ.sync { }
        guard process.terminationStatus == 0 else { return [:] }
        guard let raw = String(data: outData, encoding: .utf8) else { return [:] }

        var map: [String: String] = [:]
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let tty = String(parts[0])
            let title = String(parts[1])
            let ttyPath = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
            map[ttyPath] = title
        }
        return map
    }

    // MARK: - Helpers

    private static func exeName() -> String {
        (CommandLine.arguments[0] as NSString).lastPathComponent
    }
}
