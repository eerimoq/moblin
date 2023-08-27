import SwiftUI

struct ConnectionSettingsView: View {
    private var index: Int
    @ObservedObject private var model: Model
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.connections[self.index].name
                }, set: { value in
                    self.model.settings.database.connections[self.index].name = value
                    self.model.settings.store()
                    self.model.numberOfConnections += 0
                }))
            }
            Section("RTMP URL") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.connections[self.index].rtmpUrl
                }, set: { value in
                    self.model.settings.database.connections[self.index].rtmpUrl = value
                    self.model.settings.store()
                }))
            }
            Section("Twitch channel name") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.connections[self.index].twitchChannelName
                }, set: { value in
                    self.model.settings.database.connections[self.index].twitchChannelName = value
                    self.model.settings.store()
                }))
            }
            Section("Twitch channel id") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.connections[self.index].twitchChannelId
                }, set: { value in
                    self.model.settings.database.connections[self.index].twitchChannelId = value
                    self.model.settings.store()
                }))
            }
        }
        .navigationTitle("Connection")
    }
}

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSettingsView(index: 0, model: Model())
    }
}
