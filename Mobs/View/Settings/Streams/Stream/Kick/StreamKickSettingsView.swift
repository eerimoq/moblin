import SwiftUI

struct StreamKickSettingsView: View {
    @ObservedObject var model: Model
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
                NavigationLink(destination: TextEditView(
                    title: "Chatroom id",
                    value: stream.kickChatroomId,
                    onSubmit: submitChannelId
                )) {
                    TextItemView(name: "Chatroom id", value: stream.kickChatroomId)
                }
            } footer: {
                Text(
                    "Find your chatroom id at https://kick.com/api/v1/channels/my_user. Replace my_user with you user."
                )
            }
        }
        .navigationTitle("Kick")
    }
}
