import SwiftUI

struct StreamAfreecaTvSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitChannelName(value: String) {
        stream.afreecaTvChannelName = value
        if stream.enabled {
            model.afreecaTvChannelNameUpdated()
        }
    }

    func submitStreamId(value: String) {
        stream.afreecaTvStreamId = value
        if stream.enabled {
            model.afreecaTvStreamIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.afreecaTvChannelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: stream.afreecaTvStreamId,
                    onSubmit: submitStreamId
                )
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
    }
}
