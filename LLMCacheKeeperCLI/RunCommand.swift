import Foundation
import Darwin
import Dispatch

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
        guard let interval = Double(arguments[2]),
              interval.isFinite,
              interval > 0,
              interval <= Double(Int.max) / 1_000_000_000 else {
            Fail.print("Invalid interval: '\(arguments[2])'. Use a number > 0 in seconds.")
            exit(EXIT_FAILURE)
        }
        let intervalNanoseconds = max(1, Int(interval * 1_000_000_000))
        let intervalDelay = DispatchTimeInterval.nanoseconds(intervalNanoseconds)
        // Five percent of the interval (capped at one second) lets macOS
        // coalesce wakeups without noticeably changing the configured cadence.
        let leewayNanoseconds = min(1_000_000_000, max(1, intervalNanoseconds / 20))
        let timerLeeway = DispatchTimeInterval.nanoseconds(leewayNanoseconds)

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
        fflush(stdout)

        // Timer and signal events share a serial queue. The timer is scheduled
        // as a one-shot after each injection so slow typing never overlaps or
        // causes missed intervals to fire back-to-back.
        let schedulerQueue = DispatchQueue(label: "com.llmcachekeeper.scheduler")
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        signal(SIGINT, SIG_IGN)
        let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: schedulerQueue)
        var iteration = 0

        timer.setEventHandler {
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

            timer.schedule(deadline: .now() + intervalDelay, leeway: timerLeeway)
        }

        interruptSource.setEventHandler {
            timer.cancel()
            print("\nStopped. Exiting after \(iteration) iteration(s).")
            fflush(stdout)
            exit(EXIT_SUCCESS)
        }

        interruptSource.resume()
        timer.schedule(deadline: .now())
        timer.resume()
        dispatchMain()
    }
}

// MARK: - Fail helper
enum Fail {
    static func print(_ message: String) {
        let stdErr = FileHandle.standardError
        let data = "Error: \(message)\n".data(using: .utf8) ?? Data()
        stdErr.write(data)
    }
}
