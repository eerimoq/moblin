import Collections
import SwiftUI
import UIKit

struct DebugLogSettingsView: View {
    let model: Model
    @ObservedObject var debug: SettingsDebug
    @Binding var log: Deque<LogEntry>
    @Binding var presentingLog: Bool
    let reloadLog: () -> Void
    let clearLog: () -> Void

    private func isMessageVisible(message: String) -> Bool {
        debug.logFilter.isEmpty || message.lowercased().contains(debug.logFilter.lowercased())
    }

    private func share() {
        let url = model.formatLog(log: log.filter { isMessageVisible(message: $0.message) })
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        getRootViewController()?.present(activityViewController, animated: true)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        share()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
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
