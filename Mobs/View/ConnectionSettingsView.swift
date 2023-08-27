import SwiftUI

struct ConnectionSettingsView: View {
    private var index: Int
    @ObservedObject private var model: Model
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }
    
    var connection: SettingsConnection {
        get {
            model.settings.database.connections[self.index]
        }
    }
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    connection.name
                }, set: { value in
                    connection.name = value
                    self.model.store()
                    self.model.numberOfConnections += 0
                }))
            }
            Section("RTMP URL") {
                TextField("", text: Binding(get: {
                    connection.rtmpUrl
                }, set: { value in
                    connection.rtmpUrl = value
                    self.model.store()
                }))
            }
            Section("Twitch channel name") {
                TextField("", text: Binding(get: {
                    connection.twitchChannelName
                }, set: { value in
                    connection.twitchChannelName = value
                    self.model.store()
                }))
            }
            Section("Twitch channel id") {
                TextField("", text: Binding(get: {
                    connection.twitchChannelId
                }, set: { value in
                    connection.twitchChannelId = value
                    self.model.store()
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
