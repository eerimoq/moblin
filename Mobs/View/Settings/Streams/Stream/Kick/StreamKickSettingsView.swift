import SwiftUI

struct StreamKickSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream

    func submitChannelId(value: String) {
        stream.kickChannelId = value
        model.store()
        if stream.enabled {
            model.kickChannelIdUpdated()
        }
    }

    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(
                title: "Channel id",
                value: stream.kickChannelId!,
                onSubmit: submitChannelId
            )) {
                TextItemView(name: "Channel id", value: stream.kickChannelId!)
            }
        }
        .navigationTitle("Kick")
    }
}
