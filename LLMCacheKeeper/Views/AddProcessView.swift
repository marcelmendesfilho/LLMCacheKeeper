import SwiftUI

struct AddProcessView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var pid: String
    @State private var selectedTTY: String = ""
    @State private var selectedCommand: String = ""
    @State private var text: String
    @State private var interval: String
    @State private var typingDelay: String
    @State private var binaryPath: String
    @State private var useSudo: Bool
    @State private var showingPIDPicker = false

    private let processID: UUID
    private let isEditing: Bool
    private let onSave: (ProcessParameters) -> Void

    init(
        defaultBinaryPath: String = "",
        defaultUseSudo: Bool = true,
        parameters: ProcessParameters? = nil,
        onSave: @escaping (ProcessParameters) -> Void
    ) {
        let initialParameters = parameters ?? ProcessParameters(
            name: "",
            pid: "",
            text: "",
            interval: "5",
            typingDelay: "5",
            binaryPath: defaultBinaryPath,
            useSudo: defaultUseSudo
        )

        processID = initialParameters.id
        isEditing = parameters != nil
        self.onSave = onSave
        _name = State(initialValue: initialParameters.name)
        _pid = State(initialValue: initialParameters.pid)
        _text = State(initialValue: initialParameters.text)
        _interval = State(initialValue: initialParameters.interval)
        _typingDelay = State(initialValue: initialParameters.typingDelay)
        _binaryPath = State(initialValue: initialParameters.binaryPath)
        _useSudo = State(initialValue: initialParameters.useSudo)
    }

    private var isValid: Bool {
        guard Int(pid) != nil, !text.isEmpty,
              Double(interval) != nil, Double(interval)! > 0
        else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit LLMCacheKeeper" : "New LLMCacheKeeper")
                .font(.title2.bold())

            Form {
                Section("Identity") {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                Section("Target") {
                    HStack {
                        TextField("PID", text: $pid)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        if !selectedCommand.isEmpty {
                            Text("\(selectedCommand)  ·  \(selectedTTY)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Pick…") {
                            showingPIDPicker = true
                        }
                    }
                    TextField("Binary path", text: $binaryPath)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Use sudo", isOn: $useSudo)
                }
                Section("Injection") {
                    TextField("Text to type", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    HStack {
                        TextField("Interval (s)", text: $interval)
                            .textFieldStyle(.roundedBorder)
                        TextField("Typing delay (ms)", text: $typingDelay)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Start") {
                    let params = ProcessParameters(
                        id: processID,
                        name: name,
                        pid: pid,
                        text: text,
                        interval: interval,
                        typingDelay: typingDelay,
                        binaryPath: binaryPath,
                        useSudo: useSudo
                    )
                    onSave(params)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 520, height: 480)
        .sheet(isPresented: $showingPIDPicker) {
            PIDPickerView(binaryPath: binaryPath) { entry in
                pid = "\(entry.pid)"
                selectedTTY = entry.tty
                selectedCommand = entry.command
            }
        }
    }

}
