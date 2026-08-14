import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var presentedSheet: ProcessSheet?
    @State private var selectedID: UUID?
    @State private var showingStopAllConfirmation = false
    @State private var showingEditUnavailableAlert = false
    @State private var unavailableEditStatus = ProcessStatus.idle

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(320)
                .alert(
                    "Editing Unavailable",
                    isPresented: $showingEditUnavailableAlert,
                    presenting: unavailableEditStatus
                ) { _ in
                } message: { status in
                    Text("This item can only be edited when its status is Stopped. Its current status is \(status.rawValue.capitalized).")
                }
        } detail: {
            if let selectedID,
               let proc = appState.processes.first(where: { $0.id == selectedID }) {
                LogView(process: proc)
            } else {
                emptyDetail
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .add:
                AddProcessView(
                    defaultBinaryPath: appState.binaryPath,
                    defaultUseSudo: appState.useSudo,
                    onSave: addProcess
                )
            case .edit(let process):
                AddProcessView(
                    parameters: process.parameters,
                    onSave: { appState.updateProcess(id: process.id, parameters: $0) }
                )
            }
        }
        .alert("Stop All LLMCacheKeepers?", isPresented: $showingStopAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Stop All", role: .destructive) {
                appState.stopAll()
            }
        } message: {
            Text("This will stop all \(appState.processes.filter { $0.status == .running }.count) running process(es).")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentedSheet = .add
                } label: {
                    Label("New LLMCacheKeeper", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button {
                    showingStopAllConfirmation = true
                } label: {
                    Label("Stop All", systemImage: "stop.circle")
                }
                .disabled(appState.processes.isEmpty)
                .help("Stop all running processes")
            }
        }
    }

    private var sidebar: some View {
        Group {
            if appState.processes.isEmpty {
                ContentUnavailableView(
                    "No LLMCacheKeepers",
                    systemImage: "tray",
                    description: Text("Click + to launch a new LLMCacheKeeper process")
                )
            } else {
                List {
                    ForEach(appState.processes) { proc in
                        ProcessRowView(
                            process: proc,
                            onStop: { proc.stop() },
                            onRestart: {
                                Task { @MainActor in
                                    await proc.restart()
                                }
                            },
                            onSelect: { selectedID = proc.id },
                            onDoubleClick: { editProcess(proc) },
                            isSelected: selectedID == proc.id
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let idx = appState.processes.firstIndex(where: { $0.id == proc.id }) {
                                    appState.removeProcess(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("LLMCacheKeepers")
        .navigationSubtitle("\(appState.processes.count) process(es)")
    }

    private var emptyDetail: some View {
        ContentUnavailableView(
            "Select a LLMCacheKeeper",
            systemImage: "rectangle.split.2x1",
            description: Text("Choose a process in the sidebar to view its output")
        )
    }

    private func addProcess(parameters: ProcessParameters) {
        appState.binaryPath = parameters.binaryPath
        appState.useSudo = parameters.useSudo
        appState.addProcess(parameters: parameters)
    }

    private func editProcess(_ process: LLMCacheKeeperProcess) {
        selectedID = process.id

        guard process.status == .stopped else {
            unavailableEditStatus = process.status
            showingEditUnavailableAlert = true
            return
        }

        presentedSheet = .edit(process)
    }
}
