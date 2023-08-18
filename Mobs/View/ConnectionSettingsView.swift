import SwiftUI

struct ConnectionSettingsView: View {
    @AppStorage("connectionName") var name: String = ""
    @AppStorage("uri") var url: String = defaultConfig.uri
    @AppStorage("streamName") var streamName: String = defaultConfig.streamName
    @AppStorage("twitchChatChannel") var twitchChatChannel: String = defaultConfig.twitchChatChannel
    @AppStorage("twitchChannelId") var twitchChannelId: String = defaultConfig.twitchChannelId
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: $name)
            }
            Section("RTMP URL") {
                TextField(defaultConfig.uri, text: $url)
                    .onSubmit {
                        print(self.url)
                    }
            }
            Section("RTMP stream name") {
                TextField(defaultConfig.streamName, text: $streamName)
                    .onSubmit {
                        print(self.url)
                    }
            }
            Section("Twitch channel name") {
                TextField(defaultConfig.twitchChatChannel, text: $twitchChatChannel)
                    .onSubmit {
                        print(self.twitchChatChannel)
                    }
            }
            Section("Twitch channel id") {
                TextField(defaultConfig.twitchChannelId, text: $twitchChannelId)
                    .onSubmit {
                        print(self.twitchChannelId)
                    }
            }
        }
        .navigationTitle("Connection")
    }
}

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSettingsView(name: "Test")
    }
}
