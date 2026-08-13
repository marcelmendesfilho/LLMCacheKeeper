import Foundation
import Darwin

// MARK: - SIGINT flag (referenced by the C signal handler)
fileprivate var LLMCacheKeeperCLIStopped: Bool = false

// MARK: - RunCommand (default mode)
enum RunCommand {
    static func run(arguments: [String]) {
        guard arguments.count >= 3 else {
            Fail.print("Usage: <pid> <text> <interval_seconds> [typing_delay_ms]. See -help.")
            exit(EXIT_FAILURE)
        }

        // Parse PID
        guard let pid = Int32(arguments[0]) else {
            Fail.print(InjectorError.pidNotNumeric(arguments[0]).description)
            exit(EXIT_FAILURE)
        }

        let text = arguments[1]

        // Parse interval in seconds (accepts decimals)
        guard let interval = Double(arguments[2]), interval > 0 else {
            Fail.print("Invalid interval: '\(arguments[2])'. Use a number > 0 in seconds.")
            exit(EXIT_FAILURE)
        }

        // Optional inter-character delay (default 5ms). Mimics human typing to
        // bypass paste detection in modern TUI apps (Codex/Claude) that would
        // otherwise treat ENTER as a newline instead of submit.
        var typingDelayMs: useconds_t = 5_000
        if arguments.count >= 4 {
            if let ms = UInt32(arguments[3]) {
                typingDelayMs = useconds_t(ms * 1000)
            } else {
                Fail.print("Invalid typing_delay_ms: '\(arguments[3])'. Use an integer in milliseconds.")
                exit(EXIT_FAILURE)
            }
        }
        // Extra pause (3x the typing delay) before ENTER, ensuring the last
        // character has already been processed by the target app.
        let preEnterDelayUs: useconds_t = typingDelayMs * 3

        // Verify the PID exists
        guard Injector.pidExists(pid) else {
            Fail.print(InjectorError.pidNotFound(pid).description)
            exit(EXIT_FAILURE)
        }

        // Resolve TTY
        let ttyPath: String
        do {
            ttyPath = try Injector.resolveTTYPath(forPID: pid)
        } catch {
            Fail.print(String(describing: error))
            exit(EXIT_FAILURE)
        }

        // Verify that the device exists
        guard FileManager.default.fileExists(atPath: ttyPath) else {
            Fail.print(InjectorError.ttyDoesNotExist(ttyPath).description)
            exit(EXIT_FAILURE)
        }

        // Pre-check root: TIOCSTI on macOS 26+ requires euid=0.
        // Failing before starting the loop keeps output clean.
        if geteuid() != 0 {
            Fail.print(InjectorError.notRoot.description)
            exit(EXIT_FAILURE)
        }

        // SIGINT handler (Ctrl-C) — a C signal handler cannot capture local
        // scope, so we use a module-level flag.
        LLMCacheKeeperCLIStopped = false
        signal(SIGINT) { _ in LLMCacheKeeperCLIStopped = true }

        // Banner
        print("LLMCacheKeeperCLI started.")
        print("  PID:        \(pid)")
        print("  TTY:        \(ttyPath)")
        print("  Text:       \(text.count) byte(s) + ENTER (\\r)")
        print("  Interval:   \(interval) s")
        print("  Typing:     \(typingDelayMs / 1000)ms between chars; \(preEnterDelayUs / 1000)ms before ENTER")
        print("  Method:     TIOCSTI (direct ioctl on /dev/tty)")
        print("  Root:       \(getuid() == 0 ? "yes" : "no")")
        print("Press Ctrl-C to stop.")

        var iteration = 0

        while !LLMCacheKeeperCLIStopped {
            iteration += 1
            // Check PID before each injection
            guard Injector.pidExists(pid) else {
                Fail.print("PID \(pid) disappeared (session terminated). Aborting.")
                exit(EXIT_FAILURE)
            }

            do {
                // 1) Inject the text with pauses between chars (mime human).
                try Injector.inject(ttyPath: ttyPath, payload: text, interCharDelayUs: typingDelayMs)
                // 2) Extra pause before ENTER to ensure processing.
                if preEnterDelayUs > 0 {
                    usleep(preEnterDelayUs)
                }
                // 3) Inject the ENTER (\r) in isolation.
                try Injector.inject(ttyPath: ttyPath, payload: "\r", interCharDelayUs: 0)
                let ts = ISO8601DateFormatter().string(from: Date())
                print("[\(ts)] \(text)")
                fflush(stdout)
            } catch let e as InjectorError {
                Fail.print(e.description)
                exit(EXIT_FAILURE)
            } catch {
                Fail.print(String(describing: error))
                exit(EXIT_FAILURE)
            }

            // Fractional sleep so we respond to SIGINT promptly
            let totalMillis = UInt32(interval * 1000)
            let chunkMs: UInt32 = 100
            var remaining = totalMillis
            while remaining > 0 && !LLMCacheKeeperCLIStopped {
                let sleepMs = min(remaining, chunkMs)
                usleep(sleepMs * 1000)
                if remaining >= sleepMs { remaining -= sleepMs } else { remaining = 0 }
            }
        }

        print("\nStopped. Exiting after \(iteration) iteration(s).")
        exit(EXIT_SUCCESS)
    }
}

// MARK: - Fail helper
enum Fail {
    static func print(_ message: String) {
        var stdErr = FileHandle.standardError
        let data = "Error: \(message)\n".data(using: .utf8) ?? Data()
        stdErr.write(data)
    }
}
