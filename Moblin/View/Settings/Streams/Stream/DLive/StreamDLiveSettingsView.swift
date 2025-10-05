import SwiftUI

struct StreamDLiveSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    private func submitStreamerUsername(value: String) {
        stream.dliveStreamerUsername = value
        if stream.enabled {
            model.dliveStreamerUsernameUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Streamer username"),
                    value: stream.dliveStreamerUsername,
                    onSubmit: submitStreamerUsername
                )
            } footer: {
                Text("Enter the DLive username of the channel you want to watch.")
            }
            Section {
                Toggle("Enabled", isOn: $stream.dliveLoggedIn)
                    .onChange(of: stream.dliveLoggedIn) { _ in
                        if stream.enabled {
                            model.dliveEnabledUpdated()
                        }
                    }
            } footer: {
                Text("Enable to connect to DLive chat.")
            }
        }
        .navigationTitle("DLive")
    }
}
