import SwiftUI

struct DebugLogSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        ScrollView {
            if model.log.isEmpty {
                Text("The log is empty.")
            } else {
                VStack {
                    ForEach(model.log) { item in
                        HStack {
                            Text(item.message)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    ShareLink(item: model.formatLog())
                    Button(action: {
                        model.clearLog()
                    }, label: {
                        Image(systemName: "trash")
                    })
                }
            }
        }
    }
}
