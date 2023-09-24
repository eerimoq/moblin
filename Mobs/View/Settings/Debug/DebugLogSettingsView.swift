import SwiftUI

struct DebugLogSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        if model.log.isEmpty {
            Text("The log is empty.")
                .navigationTitle("Log")
        } else {
            HStack {
                Spacer()
                Button(action: {
                    model.clearLog()
                }, label: {
                    Text("Clear")
                        .padding(5)
                        .foregroundColor(.blue)
                })
            }
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(model.log) { message in
                        HStack {
                            Text(message.message)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Log")
        }
    }
}
