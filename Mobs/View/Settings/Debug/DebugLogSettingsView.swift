import SwiftUI

struct DebugLogSettingsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        if model.log.isEmpty {
            Text("The log is empty.")
                .navigationTitle("Log")
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(model.log, id: \.self) { message in
                        HStack {
                            Text(message)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Log")
        }
    }
}
