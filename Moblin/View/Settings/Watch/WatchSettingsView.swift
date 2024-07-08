import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: WatchChatSettingsView(fontSize: model.database.watch!.chat
                        .fontSize))
                {
                    Text("Chat")
                }
                NavigationLink(destination: WatchDisplaySettingsView()) {
                    Text("Display")
                }
            } footer: {
                Text("""
                The watch acts as a remote control assistant as \
                soon as a remote control streamer is connected. \
                Please note that in this case, chat is not (yet) available.
                """)
            }
        }
        .navigationTitle("Watch")
        .toolbar {
            SettingsToolbar()
        }
    }
}
