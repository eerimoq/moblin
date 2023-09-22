import SwiftUI

struct StreamSettingsView: View {
    @ObservedObject private var model: Model
    private var stream: SettingsStream

    init(stream: SettingsStream, model: Model) {
        self.model = model
        self.stream = stream
    }

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
                TextItemView(name: "Name", value: stream.name)
            }
            NavigationLink(destination: StreamUrlSettingsView(
                model: model,
                stream: stream
            )) {
                TextItemView(name: "URL", value: schemeAndAddress(url: stream.url!))
            }
            NavigationLink(destination: StreamVideoSettingsView(
                model: model,
                stream: stream
            )) {
                Text("Video")
            }
            NavigationLink(destination: StreamTwitchSettingsView(
                model: model,
                stream: stream
            )) {
                Text("Twitch")
            }
            NavigationLink(destination: StreamKickSettingsView(
                model: model,
                stream: stream
            )) {
                Text("Kick")
            }
        }
        .navigationTitle("Stream")
    }
}
