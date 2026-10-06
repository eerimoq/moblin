import SwiftUI

struct WatchSettingsView: View {
    let model: Model
    @ObservedObject var watch: WatchSettings

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WatchChatSettingsView(model: model, chat: model.database.watch.chat)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    WatchDisplaySettingsView(show: watch.show)
                } label: {
                    Text("Display")
                }
            }
            Section {
                Toggle("Remote control assistant", isOn: $watch.viaRemoteControl)
                    .onChange(of: watch.viaRemoteControl) { _ in
                        model.sendInitToWatch()
                    }
            } footer: {
                Text("""
                The watch acts as remote control assistant when enabled. Please note that in this \
                case, chat, skip current TTS and a few other features are not supported.
                """)
            }
        }
        .navigationTitle("Apple Watch")
    }
}
