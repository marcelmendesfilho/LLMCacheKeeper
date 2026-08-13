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
                Text("Select a PID")
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
                TextField("Filter by PID, TTY, command or tab title", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await load() } }
            }
            .padding(8)
            .background(.regularMaterial)
            .padding([.horizontal, .top], 10)

            if entries.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No sessions found",
                    systemImage: "terminal",
                    description: Text("Make sure the CLI binary path is correct and run \(binaryPath) -list in a terminal to verify.")
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
                Text("\(entry.pid)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .frame(width: 60, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                Text(entry.tty)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                Text(entry.command)
                    .font(.callout)
                    .lineLimit(1)
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
