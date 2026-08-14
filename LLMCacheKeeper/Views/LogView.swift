import SwiftUI

struct LogView: View {
    @Bindable var process: LLMCacheKeeperProcess
    private let bottomID = "log-bottom"

    var body: some View {
        VStack(spacing: 0) {
            ParametersHeaderView(
                parameters: process.parameters,
                status: process.status,
                startedAt: process.startedAt
            )
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(process.output.isEmpty ? "No output yet." : process.output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(8)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: process.output) { _, _ in
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
                .onAppear {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
        .navigationSubtitle(process.status.rawValue)
    }
}
