import Collections
import SwiftUI

struct DebugLogSettingsView: View {
    let model: Model
    @Binding var log: Deque<LogEntry>
    @Binding var presentingLog: Bool
    let clearLog: () -> Void
    @State private var filter: String = ""

    private func isMessageVisible(message: String) -> Bool {
        return filter.isEmpty || message.lowercased().contains(filter.lowercased())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Filter", text: $filter)
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
                    ShareLink(item: model.formatLog(log: log.filter { isMessageVisible(message: $0.message) }))
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
                        presentingLog = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
