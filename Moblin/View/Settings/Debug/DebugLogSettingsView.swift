import Collections
import SwiftUI

struct DebugLogSettingsView: View {
    var log: Deque<LogEntry>
    var formatLog: () -> String
    var clearLog: () -> Void
    var quickDone: (() -> Void)?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                ShareLink(item: formatLog())
                Button(action: {
                    clearLog()
                }, label: {
                    Image(systemName: "trash")
                })
            }
            ScrollView {
                if log.isEmpty {
                    Text("The log is empty.")
                } else {
                    LazyVStack {
                        ForEach(log) { item in
                            HStack {
                                Text(item.message)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            SettingsToolbar(quickDone: quickDone)
        }
    }
}
