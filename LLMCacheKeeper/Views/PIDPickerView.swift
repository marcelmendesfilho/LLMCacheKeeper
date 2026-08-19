import SwiftUI

struct PIDPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let binaryPath: String
    let onSelect: (PIDEntry) -> Void

    @State private var entries: [PIDEntry] = []
    @State private var isLoading = false
    @State private var searchText = ""

    private var filtered: [PIDEntry] {
        guard !searchText.isEmpty else { return entries }
        let q = searchText.lowercased()
        return entries.filter {
            "\($0.pid) \($0.tty) \($0.command) \($0.tabTitle)".lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select an Agent Session")
                    .font(.title2.bold())
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Refresh") {
                        Task { await load() }
                    }
                }
            }
            .padding(12)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by agent, TTY, PID or tab title", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await load() } }
            }
            .padding(8)
            .background(.regularMaterial)
            .padding([.horizontal, .top], 10)

            if entries.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Valid Agent Sessions",
                    systemImage: "terminal",
                    description: Text("Start Codex, Claude, or OpenCode in a terminal session. Outer multiplexer terminals and idle shells are hidden.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(filtered) { entry in
                    PIDPickerRow(entry: entry) {
                        onSelect(entry)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 520, height: 420)
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        entries = await PIDScanner.scan(binaryPath: binaryPath)
        isLoading = false
    }
}

private struct PIDPickerRow: View {
    let entry: PIDEntry
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(entry.command)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .frame(width: 90, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                Text(entry.tty)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                Text("PID \(entry.pid)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.tabTitle.isEmpty {
                    Text(entry.tabTitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .trailing)
                }
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
