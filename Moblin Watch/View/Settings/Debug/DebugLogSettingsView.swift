import Collections
import SwiftUI

struct DebugLogSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack {
            ScrollView {
                if model.log.isEmpty {
                    Text("The log is empty.")
                } else {
                    LazyVStack {
                        ForEach(model.log) { item in
                            HStack {
                                Text(item.message)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .font(.system(size: 12))
        }
        .navigationTitle("Log")
    }
}
