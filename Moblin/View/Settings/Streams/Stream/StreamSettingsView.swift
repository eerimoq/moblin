import SwiftUI

struct StreamSettingsView: View {
    @EnvironmentObject private var model: Model
    var stream: SettingsStream

    func submitName(name: String) {
        stream.name = name
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: stream.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: stream.name)
            }
            NavigationLink(destination: StreamUrlSettingsView(
                stream: stream,
                value: stream.url
            )) {
                TextItemView(name: "URL", value: schemeAndAddress(url: stream.url))
            }
            .disabled(stream.enabled && model.isLive)
            NavigationLink(destination: StreamVideoSettingsView(stream: stream)) {
                Text("Video")
            }
            NavigationLink(destination: StreamTwitchSettingsView(stream: stream)) {
                TextItemView(name: "Twitch", value: stream.twitchChannelName)
            }
            NavigationLink(destination: StreamKickSettingsView(stream: stream)) {
                Text("Kick")
            }
            NavigationLink(destination: StreamYouTubeSettingsView(stream: stream)) {
                Text("YouTube")
            }
            NavigationLink(destination: StreamAfreecaTvSettingsView(stream: stream)) {
                Text("AfreecaTV")
            }
            NavigationLink(destination: StreamSrtSettingsView(stream: stream)) {
                Text("SRT(LA)")
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
