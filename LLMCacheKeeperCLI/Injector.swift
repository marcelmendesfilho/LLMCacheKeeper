import Foundation
import Darwin

// MARK: - TIOCSTI constant
// From <sys/ttycom.h>: #define TIOCSTI _IOW('t', 114, char) = 0x80017472
private let TIOCSTI: UInt = 0x80017472

// MARK: - Errors
enum InjectorError: Error, CustomStringConvertible {
    case pidNotFound(Int32)
    case pidNotNumeric(String)
    case ttyNotResolved(Int32)
    case ttyDoesNotExist(String)
    case openFailed(String, String)
    case injectFailed(String)
    case notRoot

    var description: String {
        switch self {
        case .pidNotFound(let pid):        return "PID \(pid) not found (no such process)."
        case .pidNotNumeric(let v):        return "Invalid PID (expected an integer): '\(v)'."
        case .ttyNotResolved(let pid):     return "Could not resolve TTY for PID \(pid) via `ps`."
        case .ttyDoesNotExist(let p):      return "TTY device does not exist or is inaccessible: \(p)."
        case .openFailed(let p, let why):  return "Failed to open \(p): \(why)."
        case .injectFailed(let why):       return "TIOCSTI injection failed: \(why)."
        case .notRoot:                     return "TIOCSTI requires root. Run with `sudo LLMCacheKeeperCLI <pid> \"text\" <seconds>`."
        }
    }
}

// MARK: - Injector
enum Injector {
    /// Checks (via kill -0) whether the process `pid` exists (any user).
    static func pidExists(_ pid: Int32) -> Bool {
        if pid <= 0 { return false }
        if kill(pid, 0) == 0 { return true }
        // ESRCH = no such process; EPERM = exists but owned by another user.
        return errno != ESRCH
    }

    /// Resolves the TTY path for `pid` (e.g. "/dev/ttys006").
    /// Uses `ps -o tty= -p <pid>` to avoid dealing with libproc internals.
    static func resolveTTYPath(forPID pid: Int32) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "tty=", "-p", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try process.run()
        } catch {
            throw InjectorError.ttyNotResolved(pid)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InjectorError.ttyNotResolved(pid)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty || raw == "??" {
            throw InjectorError.ttyNotResolved(pid)
        }
        let path = raw.hasPrefix("/dev/") ? raw : "/dev/\(raw)"
        return path
    }

    /// Opens the TTY (O_WRONLY) and injects each byte of `payload` via TIOCSTI,
    /// simulating keyboard input into the terminal connected to that TTY.
    /// Requires root (euid=0) on macOS 26+ (Tahoe) — without root it returns EPERM.
    ///
    /// `payload` should already include the terminator (\\r for ENTER) when needed.
    ///
    /// `interCharDelayUs`: delay in microseconds between each byte. Modern TUI
    /// apps (Codex/Claude/iTerm) detect byte "bursts" as paste and, in that
    /// mode, treat ENTER as a newline instead of submit. Injecting with
    /// pauses (~5ms) mimics human typing and bypasses that detection.
    static func inject(ttyPath: String, payload: String, interCharDelayUs: useconds_t = 0) throws {
        let fd = open(ttyPath, O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else {
            throw InjectorError.openFailed(ttyPath, String(cString: strerror(errno)))
        }
        defer { close(fd) }

        let bytes = Array(payload.utf8)
        for byte in bytes {
            var c = Int8(bitPattern: byte)
            // ioctl(fd, TIOCSTI, &c)
            let rc = withUnsafeMutablePointer(to: &c) { ptr -> Int32 in
                return ioctl(fd, TIOCSTI, ptr)
            }
            if rc < 0 {
                let why = String(cString: strerror(errno))
                if errno == EPERM {
                    throw InjectorError.notRoot
                }
                throw InjectorError.injectFailed(why)
            }
            if interCharDelayUs > 0 {
                usleep(interCharDelayUs)
            }
        }
    }
}

// MARK: - Executable name helper (shared)
func currentExecutableName() -> String {
    (CommandLine.arguments[0] as NSString).lastPathComponent
}