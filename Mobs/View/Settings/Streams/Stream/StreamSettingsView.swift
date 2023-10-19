import SwiftUI

struct StreamSettingsView: View {
    @ObservedObject private var model: Model
    var toolbar: Toolbar
    private var stream: SettingsStream

    init(stream: SettingsStream, model: Model, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
    }

    func submitName(name: String) {
        stream.name = name
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                toolbar: toolbar,
                name: stream.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: stream.name)
            }
            NavigationLink(destination: StreamUrlSettingsView(
                model: model,
                stream: stream,
                toolbar: toolbar
            )) {
                TextItemView(name: "URL", value: schemeAndAddress(url: stream.url))
            }
            NavigationLink(destination: StreamVideoSettingsView(
                model: model,
                toolbar: toolbar,
                stream: stream
            )) {
                Text("Video")
            }
            NavigationLink(destination: StreamTwitchSettingsView(
                model: model,
                toolbar: toolbar,
                stream: stream
            )) {
                Text("Twitch")
            }
            NavigationLink(destination: StreamKickSettingsView(
                model: model,
                toolbar: toolbar,
                stream: stream
            )) {
                Text("Kick")
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            toolbar
        }
    }
}
