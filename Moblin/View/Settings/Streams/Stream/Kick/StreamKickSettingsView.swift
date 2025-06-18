import SwiftUI

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitChannelName(value: String) {
        stream.kickChannelName = value
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onSubmit: submitChannelName
                )
            }
        }
        .navigationTitle("Kick")
    }
}
