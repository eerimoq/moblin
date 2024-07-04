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
            }
            Section {
                Toggle("Remote Control Info and Preview", isOn: Binding(get: {
                    model.database.watch!.remoteControl!
                }, set: { value in
                    model.database.watch!.remoteControl = value
                    model.store()
                }))
            } footer: {
                Text("""
                Display data and preview from the remote control streamer \
                instead of from the device connected to the watch.
                """)
            }
        }
        .navigationTitle("Watch")
        .toolbar {
            SettingsToolbar()
        }
    }
}
