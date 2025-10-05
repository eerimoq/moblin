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
        }
        .navigationTitle("DLive")
    }
}
