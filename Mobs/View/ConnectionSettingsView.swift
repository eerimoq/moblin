import SwiftUI

struct ConnectionSettingsView: View {
    var index: Int
    @ObservedObject var model: Model

    var connection: SettingsConnection {
        get {
            model.settings.database.connections[index]
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    connection.name
                }, set: { value in
                    connection.name = value
                    model.store()
                    model.numberOfConnections += 0
                }))
            }
            Section("RTMP URL") {
                TextField("", text: Binding(get: {
                    connection.rtmpUrl
                }, set: { value in
                    connection.rtmpUrl = value
                    model.store()
                }))
            }
            Section("Twitch channel name") {
                TextField("", text: Binding(get: {
                    connection.twitchChannelName
                }, set: { value in
                    connection.twitchChannelName = value
                    model.store()
                }))
            }
            Section("Twitch channel id") {
                TextField("", text: Binding(get: {
                    connection.twitchChannelId
                }, set: { value in
                    connection.twitchChannelId = value
                    model.store()
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
