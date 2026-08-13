# LLMCacheKeeper

I built this app to solve a single problem: after a period of inactivity of an LLM agent (Codex, Claude, OpenCode), the LLM backend removes the entire conversation from the cache. After that, any new message consumes a large number of tokens because the cache no longer exists. This app makes the agent send a message on your behalf at regular intervals, preventing the cache from being invalidated due to inactivity. You define the message and the interval between messages. It supports multiple agents.

---

## How it works

LLMCacheKeeper injects keystrokes directly into the TTY of a target terminal process using the `TIOCSTI` ioctl (kernel-level input injection). This means it works with **any** terminal-based LLM agent — Codex, Claude, OpenCode — running in Terminal.app, herdr, iTerm, or any other multiplexer. The agent receives the message as if you typed it yourself, and the ENTER key is sent as `\r` (carriage return) to match what raw-mode TUI apps expect.

A small inter-character delay (default 5 ms) mimics human typing speed. This is necessary because many LLM TUI apps detect "burst" input as paste and, in paste mode, treat ENTER as a newline rather than a submit. With the delay, the app bypasses paste detection and the ENTER submits the message correctly.

## Project structure

| Target | Product | Description |
|---|---|---|
| `LLMCacheKeeperCLI` | `LLMCacheKeeperCLI` (CLI binary) | Command-line tool that injects text + ENTER into a PID's TTY in a loop. |
| `LLMCacheKeeper` | `LLMCacheKeeper.app` (macOS GUI) | SwiftUI app that manages multiple CLI instances with live output, start/stop, and restart per process. |

Both targets live in the same Xcode project (`LLMCacheKeeper.xcodeproj`).

---

## Requirements

- macOS 26+ (Tahoe) — `TIOCSTI` is restricted to root starting macOS 26.
- Xcode 26 or later (Command Line Tools sufficient for the CLI).
- `sudo` access (the CLI must run as root).

## Build

Open `LLMCacheKeeper.xcodeproj` in Xcode and build both schemes, or use the command line:

```bash
# Build the CLI
xcodebuild -project LLMCacheKeeper.xcodeproj -scheme LLMCacheKeeperCLI -configuration Debug -destination 'platform=macOS' build

# Build the GUI app (automatically builds the CLI as a dependency)
xcodebuild -project LLMCacheKeeper.xcodeproj -scheme LLMCacheKeeper -configuration Debug -destination 'platform=macOS' build
```

Build products are placed in Xcode's DerivedData folder.

---

## CLI usage

```
sudo LLMCacheKeeperCLI <pid> <text> <interval_seconds> [typing_delay_ms]

  pid                Numeric PID of the target session (e.g. shell/opencode/claude/codex on /dev/ttysXXX)
  text               Text to type (will be followed by ENTER)
  interval_seconds   Time (in seconds, accepts decimals) between each injection
  typing_delay_ms    (optional) Delay in ms between each character (default 5).

LLMCacheKeeperCLI -list     Lists PIDs of running terminal sessions
LLMCacheKeeperCLI -setup   Shows macOS setup / permission instructions
LLMCacheKeeperCLI -doctor  Checks that all required permissions and conditions are met
LLMCacheKeeperCLI -help    Displays help
```

### Examples

```bash
# Find the PID of your agent session
LLMCacheKeeperCLI -list

# Inject "ping" every 30 seconds into PID 55706
sudo LLMCacheKeeperCLI 55706 "ping" 30

# Inject with a custom typing delay of 5 ms (default)
sudo LLMCacheKeeperCLI 55706 "keep alive" 60 5
```

Press `Ctrl-C` to stop the loop. The app exits with an error if the PID disappears (session closed).

---

## GUI usage

Launch `LLMCacheKeeper.app`. The interface provides:

- **Sidebar** — lists all running LLMCacheKeeper processes with name, text preview, status badge, and stop/restart button.
- **Detail pane** — shows the selected process's parameters (PID, interval, typing delay, sudo, start time) in a fixed header, followed by a live scrolling log of the CLI's stdout/stderr output.
- **Toolbar** — "New CacheKeeper" button opens a form to configure a new process (name, PID, text, interval, typing delay, binary path, sudo toggle). "Stop All" button stops all running processes after confirmation.
- **Swipe to delete** — swipe left on a sidebar row to remove a process (it is stopped first).

### Sudo in the GUI

Since the CLI requires root, the GUI app runs each process via `sudo -S` and prompts for the administrator password through a native macOS dialog (`osascript`). The password is consumed by `sudo` and **never stored**. You will be prompted each time you start or restart a process.

App Sandbox and Hardened Runtime are disabled for the GUI target so that it can spawn `sudo` and capture subprocess output.

---

## Setup and diagnostics

### `-setup`

Displays step-by-step instructions for running the CLI with `sudo`, including how to configure `NOPASSWD` in `sudoers` via `visudo` to avoid typing the password on every invocation.

### `-doctor`

Validates that all required conditions are met:

- Running as root (euid = 0)
- `/bin/ps` available (used to resolve TTY from PID)
- Read access to `/dev`
- `sudo` available at `/usr/bin/sudo`

If any check fails, the output lists the exact steps to resolve it.

---

## How to find the PID

**Inside the terminal session itself:**

```bash
echo $$
```

**From another terminal:**

```bash
LLMCacheKeeperCLI -list
```

This lists every process attached to a `ttys*` TTY, along with the command name and (when available) the Terminal.app tab title. Find the row for the shell (e.g. `zsh`, `bash`) running in the same TTY as your agent and copy its PID. TIOCSTI injects into the TTY, so targeting the shell PID ensures the keystrokes reach any process sharing that terminal — including `codex`, `claude`, or `opencode` running in the foreground.

---

## Notes

- `TIOCSTI` is a kernel-level ioctl that injects bytes directly into the TTY input buffer. It does not require the target window to be focused or visible.
- On macOS 26+ (Tahoe), `TIOCSTI` is restricted to root. Without root it returns `EPERM`. This is a macOS security change, not a bug in this app.
- The ENTER key is sent as `\r` (carriage return, 0x0D), not `\n` (line feed). Raw-mode TUI apps (Codex, Claude, OpenCode) disable the `ICRNL` translation and expect `\r`; cooked-mode terminals translate `\r` to `\n` via the line discipline. `\r` works in both cases.
- The inter-character delay (default 5 ms) prevents paste detection. Some apps may require a higher value (e.g. 80–120 ms); if ENTER does not submit, try increasing the `typing_delay_ms` parameter.

---

## License

This project is provided as-is for personal use. No warranty is expressed or implied.