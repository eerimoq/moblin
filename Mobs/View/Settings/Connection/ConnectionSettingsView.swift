import SwiftUI

func getConnection(index: Int, model: Model) -> SettingsConnection {
    return model.settings.database.connections[index]
}

struct ConnectionSettingsView: View {
    private var index: Int
    @ObservedObject private var model: Model
    @State private var rtmpUrl: String
    @State private var srtUrl: String
    @State private var srtla: Bool
    @State private var twitchChannelName: String
    @State private var twitchChannelId: String

    init(index: Int, model: Model) {
        self.index = index
        self.model = model
        let connection = model.settings.database.connections[index]
        self.rtmpUrl = connection.rtmpUrl
        self.srtUrl = "srt://foo.com/123"
        self.srtla = false
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
            NavigationLink(destination: ConnectionNameSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(connection.name).foregroundColor(.gray)
                }
            }
            NavigationLink(destination: ConnectionRtmpSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("RTMP URL")
                }
            }
            NavigationLink(destination: ConnectionTwitchSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("Twitch")
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
