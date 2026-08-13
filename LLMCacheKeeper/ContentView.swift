import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var showingAdd = false
    @State private var selectedID: UUID?
    @State private var showingStopAllConfirmation = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(320)
        } detail: {
            if let selectedID,
               let proc = appState.processes.first(where: { $0.id == selectedID }) {
                LogView(process: proc)
            } else {
                emptyDetail
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddProcessView(
                binaryPath: $appState.binaryPath,
                useSudo: $appState.useSudo,
                onAdd: { appState.addProcess(parameters: $0) }
            )
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
                    showingAdd = true
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
}