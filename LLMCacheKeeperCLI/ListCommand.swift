import Foundation
import Darwin

// MARK: - ListCommand (-list)
/// Lists the PIDs of running terminal sessions, associating each TTY with its
/// process. Combines `ps` (PID/TTY/comm) with AppleScript (visible tab title
/// in Terminal.app) to make identifying the target session easier.
enum ListCommand {
    static func run() {
        fflush(stdout)

        // 1) List processes associated with ttys* TTYs via ps.
        let psLines = runPS()
        guard !psLines.isEmpty else {
            print("No terminal with a ttys* TTY found.")
            fflush(stdout)
            return
        }

        // 2) Best-effort: map TTY -> tab title via AppleScript (Terminal.app).
        //    If Automation is slow/denied, proceeds without titles.
        let ttyTitles = fetchTerminalTabTitles(timeoutSeconds: 8)

        // 3) Output
        print("PID        TTY              COMMAND                                  TAB (Terminal.app)")
        print("---------- ---------------- --------------------------------------- ----------------")
        for line in psLines {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                .map { String($0) }
            guard parts.count >= 3 else { continue }
            let pid = parts[0]
            let tty = parts[1]
            let comm = parts[2]
            let ttyPath = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
            let title = ttyTitles[ttyPath] ?? ""
            let pidPad = pid.padding(toLength: 10, withPad: " ", startingAt: 0)
            let ttyPad = tty.padding(toLength: 16, withPad: " ", startingAt: 0)
            let commPadded = comm.padding(toLength: 39, withPad: " ", startingAt: 0)
            print("\(pidPad) \(ttyPad) \(commPadded) \(title)")
        }
        print("")
        print("\(psLines.count) session(s) listed. Use the desired PID in: \(exeName()) <pid> \"text\" <seconds>")
        fflush(stdout)
    }

    // MARK: - ps

    /// Runs `ps -e -o pid=,tty=,comm=` and returns only lines whose TTY starts
    /// with "ttys" (interactive session terminals).
    private static func runPS() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-e", "-o", "pid=,tty=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        do { try process.run() } catch { return [] }
        // Read concurrently to avoid deadlock when output exceeds the pipe
        // buffer (64 KB). If we read only after waitUntilExit, `ps` blocks on
        // write and neither completes.
        let handle = pipe.fileHandleForReading
        var outData = Data()
        let readQ = DispatchQueue(label: "list.ps.read")
        readQ.async { outData = handle.readDataToEndOfFile() }
        process.waitUntilExit()
        readQ.sync { } // wait for the read to complete
        guard process.terminationStatus == 0 else { return [] }
        guard let raw = String(data: outData, encoding: .utf8) else { return [] }
        return raw.split(separator: "\n")
            .map { String($0) }
            .filter { $0.trimmingCharacters(in: .whitespaces).contains("ttys") }
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