import Collections
import SwiftUI

struct DebugLogSettingsView: View {
    @EnvironmentObject var model: Model
    var log: Deque<LogEntry>
    var clearLog: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 15) {
                Spacer()
                ShareLink(item: model.formatLog(log: log))
                Button(action: {
                    clearLog()
                    model.objectWillChange.send()
                }, label: {
                    Image(systemName: "trash")
                })
            }
            .padding([.top], 10)
            .padding([.trailing], 15)
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
    }
}
