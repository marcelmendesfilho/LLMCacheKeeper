import SwiftUI

struct StatusBadge: View {
    let status: ProcessStatus

    private var color: Color {
        switch status {
        case .idle:    .secondary
        case .running: .green
        case .stopped: .gray
        case .failed:  .red
        }
    }

    private var label: String {
        switch status {
        case .idle:    "Idle"
        case .running: "Running"
        case .stopped: "Stopped"
        case .failed:  "Failed"
        }
    }

    private var icon: String {
        switch status {
        case .idle:    "circle.dashed"
        case .running: "circle.fill"
        case .stopped: "stop.circle.fill"
        case .failed:  "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(color)
                .font(.caption.weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
    }
}