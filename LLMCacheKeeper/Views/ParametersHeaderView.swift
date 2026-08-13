import SwiftUI

struct ParametersHeaderView: View {
    let parameters: ProcessParameters
    let status: ProcessStatus
    let startedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(parameters.name.isEmpty ? "PID \(parameters.pid)" : parameters.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: status)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ParamChip(label: "PID", value: parameters.pid)
                    ParamChip(label: "Interval", value: "\(parameters.interval)s")
                    if !parameters.typingDelay.isEmpty {
                        ParamChip(label: "Typing delay", value: "\(parameters.typingDelay)ms")
                    }
                    ParamChip(label: "Sudo", value: parameters.useSudo ? "yes" : "no")
                    if let startedAt {
                        ParamChip(label: "Started", value: startedAt.formatted(.dateTime.hour().minute().second()))
                    }
                }
            }

            Text(parameters.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}

private struct ParamChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}