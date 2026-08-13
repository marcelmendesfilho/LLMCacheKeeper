import Foundation

@Observable
final class LLMCacheKeeperProcess: Identifiable {
    let id: UUID
    let parameters: ProcessParameters

    private(set) var status: ProcessStatus = .idle
    private(set) var output: String = ""
    private(set) var startedAt: Date?
    private var wasStoppedManually = false

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    init(parameters: ProcessParameters) {
        self.id = parameters.id
        self.parameters = parameters
    }

    // MARK: - Password prompt (askpass)

    /// Shows a native macOS password dialog via osascript and returns the
    /// entered password (or nil if cancelled). Called on the main thread so
    /// the dialog appears reliably from a GUI app context.
    @MainActor
    private static func promptPassword() async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = [
            "-e",
            """
            set dlg to display dialog "LLMCacheKeeper needs your administrator password:" default answer "" with hidden answer with title "LLMCacheKeeper — sudo" buttons {"Cancel","OK"} default button "OK"
            """,
            "-e",
            """
            if button returned of dlg is "OK" then return text returned of dlg
            """
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle(forWritingAtPath: "/dev/null")
        do {
            try task.run()
        } catch {
            return nil
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let pwd = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n\r")) ?? ""
        return pwd.isEmpty ? nil : pwd
    }

    func start(password: String? = nil) async {
        guard status != .running else { return }
        output = ""
        status = .running
        startedAt = Date()
        wasStoppedManually = false

        // For sudo without a password, prompt synchronously now on main actor.
        let sudoPwd: String?
        if parameters.useSudo {
            if let p = password {
                sudoPwd = p
            } else {
                sudoPwd = await Self.promptPassword()
            }
            if sudoPwd == nil {
                appendOutput("[error] sudo password not provided. Aborting.\n")
                status = .failed
                return
            }
        } else {
            sudoPwd = nil
        }

        let proc = Process()

        var executablePath = parameters.binaryPath
        var args: [String] = [parameters.pid, parameters.text, parameters.interval]
        if !parameters.typingDelay.isEmpty {
            args.append(parameters.typingDelay)
        }
        if parameters.useSudo {
            // -S: read password from stdin (most reliable on macOS GUI apps
            // where SUDO_ASKPASS doesn't always open a dialog).
            // sudo flags MUST come before the command path.
            args.insert(executablePath, at: 0)
            args.insert("-S", at: 0)
            executablePath = "/usr/bin/sudo"
        }

        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = args

        // Inherit env; ensure PATH includes /usr/bin and /bin.
        var env = ProcessInfo.processInfo.environment
        if env["PATH"] == nil {
            env["PATH"] = "/usr/bin:/bin"
        } else if !(env["PATH"] ?? "").contains("/usr/bin") {
            env["PATH"] = (env["PATH"] ?? "") + ":/usr/bin"
        }
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        proc.standardInput = inPipe

        // Write the sudo password to stdin so `sudo -S` can consume it,
        // followed by a newline, then close the write end.
        if let pwd = sudoPwd {
            inPipe.fileHandleForWriting.write((pwd + "\n").data(using: .utf8) ?? Data())
            inPipe.fileHandleForWriting.closeFile()
        }
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let line = String(data: data, encoding: .utf8) {
                    self?.appendOutput(line)
                }
            } else {
                handle.readabilityHandler = nil
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let line = String(data: data, encoding: .utf8) {
                    self?.appendOutput(line)
                }
            } else {
                handle.readabilityHandler = nil
            }
        }

        proc.terminationHandler = { [weak self] proc in
            // drain remaining buffered output
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            if let outStr = String(data: outData, encoding: .utf8), !outStr.isEmpty {
                self?.appendOutput(outStr)
            }
            if let errStr = String(data: errData, encoding: .utf8), !errStr.isEmpty {
                self?.appendOutput(errStr)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                // Respect manual stop: don't override .stopped with .failed.
                guard !self.wasStoppedManually else { return }
                self.status = proc.terminationStatus == 0 ? .stopped : .failed
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = outPipe
            errorPipe = errPipe
        } catch {
            appendOutput("Error launching process: \(error.localizedDescription)\n")
            status = .failed
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            status = .stopped
            return
        }
        wasStoppedManually = true
        proc.terminate()

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, let p = self.process, p.isRunning else { return }
            kill(p.processIdentifier, SIGKILL)
            DispatchQueue.main.async {
                self.status = .stopped
            }
        }
        status = .stopped
    }

    func restart() async {
        // Re-run with the same parameters (will re-prompt for sudo password).
        await start()
    }

    func appendOutput(_ text: String) {
        output.append(text)
    }
}