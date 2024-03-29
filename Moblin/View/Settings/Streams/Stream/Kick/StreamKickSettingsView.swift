import SwiftUI

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitChannelId(value: String) {
        stream.kickChatroomId = value
        model.store()
        if stream.enabled {
            model.kickChatroomIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Chatroom id"),
                    value: stream.kickChatroomId,
                    onSubmit: submitChannelId
                )
            } footer: {
                Text(
                    """
                    Find your chatroom id at https://kick.com/api/v1/channels/my_user. \
                    Replace my_user with your user.
                    """
                )
            }
        }
        .navigationTitle("Kick")
        .toolbar {
            SettingsToolbar()
        }
    }
}
