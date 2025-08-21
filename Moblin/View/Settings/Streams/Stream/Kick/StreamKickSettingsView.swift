import SwiftUI

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

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

            if model.database.debug.kickLogin {
                Section {
                    NavigationLink(destination: KickAuthView(stream: stream)) {
                        HStack {
                            Image(systemName: stream
                                .kickLoggedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                                .foregroundColor(stream.kickLoggedIn ? .green : .blue)
                            Text("Authentication")
                            Spacer()
                            if stream.kickLoggedIn {
                                Text("Logged In")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Authentication is required to send chat messages")
                }
            }
        }
        .navigationTitle("Kick")
    }
}
