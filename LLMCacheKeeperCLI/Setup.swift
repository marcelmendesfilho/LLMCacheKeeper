import Foundation
import Darwin

// MARK: - Setup (-setup) and Diagnostics (-doctor)
enum Setup {

    // MARK: -setup
    /// Setup guide. PID-based injection uses the TIOCSTI ioctl on /dev/tty of
    /// the target process. On macOS 26+ (Tahoe) TIOCSTI is restricted to root,
    /// so the binary must be run via `sudo`. This works with any terminal
    /// (Terminal.app, herdr, iTerm, etc.), making it the recommended method.
    static func run() {
        print("""
        =========================
          LLMCacheKeeperCLI - setup
        =========================

        METHOD — TIOCSTI directly on /dev/tty of the PID
        LLMCacheKeeperCLI injects text into the input buffer of the target TTY.
        It works with any terminal (Terminal.app, herdr, iTerm, etc.) because
        it operates at the kernel level, regardless of app or focus.

        STEP 1  -  Run as root (sudo)
          On macOS 26+ (Tahoe) the TIOCSTI ioctl is restricted to root (without
          root it returns EPERM). Run LLMCacheKeeperCLI via:
              sudo \(exePath()) <pid> "text" <seconds>

        STEP 2 (optional)  -  Skip the password (sudoers NOPASSWD)
          If you want to run `sudo LLMCacheKeeperCLI` without entering a password
          every time, edit /etc/sudoers via `visudo` and add:
              \(userName())  ALL=(ALL) NOPASSWD: \(exePath())
          To verify that it's OK:
              sudo \(exeName()) -doctor
        """)
        print("Once done, run `sudo \(exeName()) -doctor` to verify.")
    }

    // MARK: -doctor
    /// Checks each prerequisite and reports OK / PENDING for each, listing
    /// CORRECTION STEPS for every pending item.
    static func doctor() {
        print("""
        =========================
          LLMCacheKeeperCLI - doctor
        =========================
        User:        \(userName()) (uid=\(getuid()), euid=\(geteuid()))
        Binary:      \(exePath())
        """)

        var items: [Pendency] = []
        items.append(checkRoot())
        items.append(checkPsAvailable())
        items.append(checkDevDirAccess())
        items.append(checkSudoAvailable())

        print("")
        print("Summary:")
        for p in items {
            let label = p.ok ? "[OK]      " : "[PENDING] "
            print("  \(label) \(p.title)")
            if !p.ok {
                for step in p.steps {
                    print("            - \(step)")
                }
            }
        }
        let anyPending = items.contains { !$0.ok }
        print("")
        if anyPending {
            print("Result: ISSUES FOUND. Resolve the steps above and run `-doctor` again.")
            exit(EXIT_FAILURE)
        } else {
            print("Result: All good. You can now run:")
            print("  sudo \(exeName()) <pid> \"text\" <seconds>")
            exit(EXIT_SUCCESS)
        }
    }

    // MARK: - Pendency structure
    private struct Pendency {
        let title: String
        let ok: Bool
        let steps: [String]
    }

    // MARK: - Individual checks

    private static func checkRoot() -> Pendency {
        let isRoot = geteuid() == 0
        return Pendency(
            title: "Running as root (euid=0)",
            ok: isRoot,
            steps: isRoot ? [] : [
                "Re-run via sudo: `sudo \(exeName()) -doctor`",
                "TIOCSTI (TTY input injection) requires root on macOS 26+;",
                "  without root any attempt returns EPERM and the app aborts.",
                "To skip the password, set up sudoers NOPASSWD (Step 2 of `-setup`).",
            ]
        )
    }

    private static func checkPsAvailable() -> Pendency {
        let fm = FileManager.default
        let exists = fm.isExecutableFile(atPath: "/bin/ps")
        return Pendency(
            title: "/bin/ps available to resolve the PID's TTY",
            ok: exists,
            steps: exists ? [] : [
                "Binary /bin/ps not found or not executable.",
                "Reinstall the Xcode Command Line Tools or restore /bin/ps.",
            ]
        )
    }

    private static func checkDevDirAccess() -> Pendency {
        let fm = FileManager.default
        let accessible = (try? fm.contentsOfDirectory(atPath: "/dev")) != nil
        return Pendency(
            title: "Read access to /dev to validate TTY",
            ok: accessible,
            steps: accessible ? [] : [
                "No access to /dev. Run as root.",
            ]
        )
    }

    private static func checkSudoAvailable() -> Pendency {
        let present = FileManager.default.isExecutableFile(atPath: "/usr/bin/sudo")
        return Pendency(
            title: "sudo available at /usr/bin/sudo",
            ok: present,
            steps: present ? [] : [
                "/usr/bin/sudo not found or not executable.",
                "Restore your macOS environment to bring sudo back.",
            ]
        )
    }

    // MARK: - Helpers

    private static func exeName() -> String { currentExecutableName() }

    private static func exePath() -> String {
        let arg0 = CommandLine.arguments[0]
        if arg0.hasPrefix("/") { return arg0 }
        let cwd = FileManager.default.currentDirectoryPath
        return (cwd as NSString).appendingPathComponent(arg0)
    }

    private static func userName() -> String {
        if let name = ProcessInfo.processInfo.environment["USER"], !name.isEmpty {
            return name
        }
        let uid = getuid()
        if let pw = getpwuid(uid)?.pointee, let n = pw.pw_name {
            return String(cString: n)
        }
        return "unknown"
    }
}