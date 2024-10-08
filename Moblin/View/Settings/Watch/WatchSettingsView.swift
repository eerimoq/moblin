import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WatchChatSettingsView(fontSize: model.database.watch!.chat.fontSize)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    WatchDisplaySettingsView()
                } label: {
                    Text("Display")
                }
            } footer: {
                Text("""
                The watch acts as remote control assistant when the remote control streamer is \
                connected. Please note that in this case, chat, skip current TTS and a few other \
                features are not (yet) supported.
                """)
            }
        }
        .navigationTitle("Watch")
    }
}
