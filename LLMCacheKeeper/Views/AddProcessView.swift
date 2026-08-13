import SwiftUI

struct AddProcessView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var binaryPath: String
    @Binding var useSudo: Bool

    @State private var name: String = ""
    @State private var pid: String = ""
    @State private var selectedTTY: String = ""
    @State private var selectedCommand: String = ""
    @State private var text: String = ""
    @State private var interval: String = "5"
    @State private var typingDelay: String = "5"
    @State private var showingPIDPicker = false

    private var isValid: Bool {
        guard Int(pid) != nil, !text.isEmpty,
              Double(interval) != nil, Double(interval)! > 0
        else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("New LLMCacheKeeper")
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
                Button("Start") {
                    let params = ProcessParameters(
                        name: name,
                        pid: pid,
                        text: text,
                        interval: interval,
                        typingDelay: typingDelay,
                        binaryPath: binaryPath,
                        useSudo: useSudo
                    )
                    onAdd(params)
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

    let onAdd: (ProcessParameters) -> Void
}
