import SwiftUI

func getConnection(index: Int, model: Model) -> SettingsConnection {
    return model.settings.database.connections[index]
}

struct ConnectionSettingsView: View {
    private var index: Int
    @ObservedObject private var model: Model
    @State private var name: String;
    @State private var rtmpUrl: String;
    @State private var twitchChannelName: String;
    @State private var twitchChannelId: String;

    init(index: Int, model: Model) {
        self.index = index
        self.model = model
        let connection = model.settings.database.connections[index]
        self.name = connection.name
        self.rtmpUrl = connection.rtmpUrl
        self.twitchChannelName = connection.twitchChannelName
        self.twitchChannelId = connection.twitchChannelId
    }
    
    var connection: SettingsConnection {
        get {
            model.settings.database.connections[index]
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: $name)
                    .onSubmit {
                        connection.name = name.trim()
                        model.store()
                        model.numberOfConnections += 0
                    }
            }
            Section("RTMP URL") {
                TextField("", text: $rtmpUrl)
                    .onSubmit {
                        let rtmpUrl = rtmpUrl.trim()
                        if URL(string: rtmpUrl) == nil {
                            return
                        }
                        connection.rtmpUrl = rtmpUrl
                        model.store()
                        model.rtmpUrlChanged()
                    }
            }
            Section("Twitch channel name") {
                TextField("", text: $twitchChannelName)
                    .onSubmit {
                        connection.twitchChannelName = twitchChannelName.trim()
                        model.store()
                        model.twitchChannelNameUpdated()
                    }
            }
            Section("Twitch channel id") {
                TextField("", text: $twitchChannelId)
                    .onSubmit {
                        connection.twitchChannelId = twitchChannelId.trim()
                        model.store()
                        model.twitchChannelIdUpdated()
                }
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
