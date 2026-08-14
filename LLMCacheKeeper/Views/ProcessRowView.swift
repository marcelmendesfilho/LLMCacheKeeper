import SwiftUI

struct ProcessRowView: View {
    let process: LLMCacheKeeperProcess
    let onStop: () -> Void
    let onRestart: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let isSelected: Bool

    private var title: String {
        process.parameters.name.isEmpty
            ? "PID \(process.parameters.pid)"
            : process.parameters.name
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusBadge(status: process.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(process.parameters.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if process.status == .running {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.red.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .help("Stop")
                .accessibilityLabel("Stop \(title)")
            } else {
                Button(action: onRestart) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.green)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.green.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .help("Restart")
                .accessibilityLabel("Restart \(title)")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: onDoubleClick)
        .onTapGesture { onSelect() }
        .accessibilityAction(named: "Edit", onDoubleClick)
    }
}
