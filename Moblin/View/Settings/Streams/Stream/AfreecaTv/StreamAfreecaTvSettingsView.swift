import SwiftUI

struct StreamAfreecaTvSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitChannelName(value: String) {
        stream.afreecaTvChannelName = value
        model.store()
        if stream.enabled {
            model.afreecaTvChannelNameUpdated()
        }
    }

    func submitStreamId(value: String) {
        stream.afreecaTvStreamId = value
        model.store()
        if stream.enabled {
            model.afreecaTvStreamIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Channel name"),
                    value: stream.afreecaTvChannelName!,
                    onSubmit: submitChannelName
                )) {
                    TextItemView(name: String(localized: "Channel name"), value: stream.afreecaTvChannelName!)
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Video id"),
                    value: stream.afreecaTvStreamId!,
                    onSubmit: submitStreamId
                )) {
                    TextItemView(name: String(localized: "Video id"), value: stream.afreecaTvStreamId!)
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Very experimental and very secret!")
                    Text("")
                    Text(
                        "Find your channel name (myChannelName) and video id (myVideoId) in your stream's URL."
                    )
                    Text("Example URL: https://play.afreecatv.com/myChannelName/myVideoId")
                }
            }
        }
        .navigationTitle("AfreecaTV")
        .toolbar {
            SettingsToolbar()
        }
    }
}
