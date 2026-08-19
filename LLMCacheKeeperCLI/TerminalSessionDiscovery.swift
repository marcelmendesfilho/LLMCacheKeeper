import Foundation

struct ValidTerminalSession {
    let pid: Int
    let tty: String
    let agent: SupportedAgent
}

enum TerminalSessionDiscovery {
    static func discover() -> [ValidTerminalSession] {
        guard let output = processTable() else { return [] }
        return validSessions(from: output)
    }

    static func validSessions(from processTable: String) -> [ValidTerminalSession] {
        let processes = processTable
            .split(separator: "\n")
            .compactMap(TerminalProcess.init(psLine:))
            .filter { $0.tty.hasPrefix("ttys") }

        return Dictionary(grouping: processes, by: \TerminalProcess.tty)
            .compactMap { tty, processes in
                let agentProcesses = processes
                    .filter(\.isInForegroundProcessGroup)
                    .compactMap { process -> (TerminalProcess, SupportedAgent)? in
                        guard let agent = SupportedAgent.matching(command: process.command) else {
                            return nil
                        }
                        return (process, agent)
                    }
                    .sorted { lhs, rhs in
                        let lhsIsLeader = lhs.0.pid == lhs.0.foregroundProcessGroupID
                        let rhsIsLeader = rhs.0.pid == rhs.0.foregroundProcessGroupID
                        if lhsIsLeader != rhsIsLeader { return lhsIsLeader }
                        return lhs.0.pid < rhs.0.pid
                    }

                guard let (process, agent) = agentProcesses.first else { return nil }
                return ValidTerminalSession(pid: process.pid, tty: tty, agent: agent)
            }
            .sorted {
                if $0.agent.rawValue != $1.agent.rawValue {
                    return $0.agent.rawValue < $1.agent.rawValue
                }
                return $0.tty.localizedStandardCompare($1.tty) == .orderedAscending
            }
    }

    private static func processTable() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = [
            "-e",
            "-o",
            "pid=,ppid=,pgid=,tpgid=,tty=,comm=",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
