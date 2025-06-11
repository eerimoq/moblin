import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WatchChatSettingsView(fontSize: model.database.watch.chat.fontSize, notificationRate: model.database.watch.chat.notificationRate ?? 1)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    WatchDisplaySettingsView()
                } label: {
                    Text("Display")
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.watch.viaRemoteControl!
                }, set: { value in
                    model.database.watch.viaRemoteControl = value
                    model.sendInitToWatch()
                })) {
                    Text("Remote control assistant")
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
