import Foundation

// MARK: - Entry point

func printUsage() {
    let exe = (CommandLine.arguments[0] as NSString).lastPathComponent
    let lines = [
        "Usage:",
        "  sudo \(exe) <pid> <text> <interval_seconds> [typing_delay_ms]   Injects text + ENTER into the target PID's terminal in a loop",
        "  \(exe) -list                                Lists supported agents on valid leaf TTYs",
        "  \(exe) -setup                               Shows macOS setup / permission instructions",
        "  \(exe) -doctor                              Checks that all required permissions and conditions are met",
        "  \(exe) -help                                Displays this help",
        "",
        "Loop parameters (runs until Ctrl-C):",
        "  pid                  Numeric PID of the target session (e.g. shell/opencode/claude/codex on /dev/ttysXXX)",
        "  text                 Text to type (will be followed by ENTER)",
        "  interval_seconds     Time (in seconds, accepts decimals) between each injection",
        "  typing_delay_ms      (optional) Delay in ms between each character (default 5).",
        "                      TUI apps (Codex/Claude) detect 'burst' input as paste and treat",
        "                      ENTER as a newline; >0 mimics human typing.",
        "",
        "Method:",
        "  TIOCSTI directly into /dev/tty of the PID (kernel-level). Works with any terminal:",
        "  Terminal.app, herdr (multiple panes), iTerm, etc. — does not require focus.",
        "  On macOS 26+ (Tahoe) TIOCSTI requires root — without root it returns EPERM. Run via `sudo`.",
        "",
        "  If the PID does not exist, or disappears during the loop, the app aborts with an error.",
    ]
    print(lines.joined(separator: "\n"))
}

let arguments = Array(CommandLine.arguments.dropFirst())

guard !arguments.isEmpty else {
    printUsage()
    exit(EXIT_FAILURE)
}

switch arguments[0] {
case "-help", "--help", "-h":
    printUsage()
    exit(EXIT_SUCCESS)
case "-list":
    ListCommand.run()
    exit(EXIT_SUCCESS)
case "-setup":
    Setup.run()
    exit(EXIT_SUCCESS)
case "-doctor":
    Setup.doctor()
    exit(EXIT_SUCCESS)
default:
    RunCommand.run(arguments: arguments)
}
