import Foundation

enum ProcessSheet: Identifiable {
    case add
    case edit(LLMCacheKeeperProcess)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let process):
            "edit-\(process.id.uuidString)"
        }
    }
}
