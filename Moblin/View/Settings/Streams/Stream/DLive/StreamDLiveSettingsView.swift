import SwiftUI

struct StreamDLiveSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    private func submitStreamerUsername(value: String) {
        stream.dLiveUsername = value
        if stream.enabled {
            model.dliveStreamerUsernameUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Username"),
                    value: stream.dLiveUsername,
                    onSubmit: submitStreamerUsername
                )
            }
        }
        .navigationTitle("DLive")
    }
}
