import Collections
import SwiftUI

struct DebugLogSettingsView: View {
    let model: Model
    @ObservedObject var debug: SettingsDebug
    @Binding var log: Deque<LogEntry>
    @Binding var presentingLog: Bool
    let reloadLog: () -> Void
    let clearLog: () -> Void

    private func isMessageVisible(message: String) -> Bool {
        return debug.logFilter.isEmpty || message.lowercased().contains(debug.logFilter.lowercased())
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
                        VStack(alignment: .leading) {
                            ForEach(log) { item in
                                if isMessageVisible(message: item.message) {
                                    HStack {
                                        Text(item.message)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: model
                        .formatLog(log: log.filter { isMessageVisible(message: $0.message) }))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        log.removeAll()
                        clearLog()
                    } label: {
                        Image(systemName: "trash")
                    }
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
