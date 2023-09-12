import SwiftUI

struct StreamTwitchSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    
    func submitChannelName(value: String) {
        stream.twitchChannelName = value
        model.store()
        if stream.enabled {
            model.twitchChannelNameUpdated()
        }
    }
    
    func submitChannelId(value: String) {
        stream.twitchChannelId = value
        model.store()
        if stream.enabled {
            model.twitchChannelIdUpdated()
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(title: "Channel name", value: stream.twitchChannelName, onSubmit: submitChannelName)) {
                TextItemView(name: "Channel name", value: stream.twitchChannelName)
            }
            NavigationLink(destination: TextEditView(title: "Channel id", value: stream.twitchChannelId, onSubmit: submitChannelId)) {
                TextItemView(name: "Channel id", value: stream.twitchChannelId)
            }
        }
        .navigationTitle("Twitch")
    }
}
