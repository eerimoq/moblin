import SwiftUI
import WatchConnectivity

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView()) {
                    Text("Log")
                }
                HStack {
                    Text("Messages")
                    Spacer()
                    Text(String(model.numberOfMessagesReceived))
                }
            }
        }
    }
}
