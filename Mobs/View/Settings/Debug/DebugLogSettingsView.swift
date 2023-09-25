import SwiftUI

struct DebugLogSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                model.copyLog()
            }, label: {
                Text("Copy")
                    .padding(5)
                    .foregroundColor(.blue)
            })
            Button(action: {
                model.clearLog()
            }, label: {
                Text("Clear")
                    .padding(5)
                    .foregroundColor(.blue)
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
        .navigationTitle("Log")
    }
}
