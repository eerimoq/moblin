import Collections
import SwiftUI

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct DebugLogSettingsView: View {
    let model: Model
    @ObservedObject var debug: SettingsDebug
    @Binding var log: Deque<LogEntry>
    @Binding var presentingLog: Bool
    let reloadLog: () -> Void
    let clearLog: () -> Void
    @State private var shareItem: ShareItem?

    private var filteredLog: Deque<LogEntry> {
        let filter = debug.logFilter.lowercased()
        return log.filter { filter.isEmpty || $0.message.lowercased().contains(filter) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Filter", text: $debug.logFilter)
                        .autocorrectionDisabled()
                }
                Section {
                    if log.isEmpty {
                        Text("The log is empty.")
                    } else {
                        ForEach(filteredLog) { item in
                            HStack {
                                Text(item.message)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                    }
                }
                .environment(\.defaultMinListRowHeight, 0)
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            // Workaround for bugged ShareLink. Cannot scroll vertically in it.
            .sheet(item: $shareItem) { item in
                ShareSheetView(activityItems: [item.url])
                    .presentationDetents([.medium, .large])
                    .presentationCompactAdaptation(.none)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareItem = ShareItem(url: model.formatLog(log: filteredLog))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(log.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        log.removeAll()
                        clearLog()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(log.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        reloadLog()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                CloseToolbar(presenting: $presentingLog)
            }
        }
    }
}
