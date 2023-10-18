import SwiftUI

struct DebugLogSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack {
            HStack {
                Spacer()
                ShareLink(item: model.formatLog())
                Button(action: {
                    model.clearLog()
                }, label: {
                    Image(systemName: "trash")
                })
            }
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
        }
        .navigationTitle("Log")
    }
}
