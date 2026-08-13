import SwiftUI

struct LogView: View {
    @Bindable var process: LLMCacheKeeperProcess

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
                ScrollView {
                    Text(process.output.isEmpty ? "No output yet." : process.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("bottom")
                }
                .onChange(of: process.output) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .navigationSubtitle(process.status.rawValue)
    }
}