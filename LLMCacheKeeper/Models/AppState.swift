import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var processes: [LLMCacheKeeperProcess] = []
    var binaryPath: String = "/Users/marcelmendes/Library/Developer/Xcode/DerivedData/LLMCacheKeeper-dwusfnwbibofstgmtuxsemvuygzv/Build/Products/Debug/LLMCacheKeeperCLI"
    var useSudo: Bool = true

    func addProcess(parameters: ProcessParameters) {
        let proc = LLMCacheKeeperProcess(parameters: parameters)
        processes.append(proc)
        Task { @MainActor in
            await proc.start()
        }
    }

    func removeProcess(at offsets: IndexSet) {
        offsets.compactMap { processes[$0] }.forEach { $0.stop() }
        processes.remove(atOffsets: offsets)
    }

    func stopAll() {
        processes.forEach { $0.stop() }
    }
}