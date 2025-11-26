import SwiftUI

struct StreamSoopSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    func submitChannelName(value: String) {
        stream.soopChannelName = value
        if stream.enabled {
            model.soopChannelNameUpdated()
        }
    }

    func submitStreamId(value: String) {
        stream.soopStreamId = value
        if stream.enabled {
            model.soopStreamIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.soopChannelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: stream.soopStreamId,
                    onSubmit: submitStreamId
                )
            } footer: {
                VStack(alignment: .leading) {
                    Text("Very experimental and very secret!")
                    Text("")
                    Text(
                        "Find your channel name (myChannelName) and video id (myVideoId) in your stream's URL."
                    )
                    Text("Example URL: https://play.sooplive.co.kr/myChannelName/myVideoId")
                }
            }
        }
        .navigationTitle("SOOP")
    }
}
