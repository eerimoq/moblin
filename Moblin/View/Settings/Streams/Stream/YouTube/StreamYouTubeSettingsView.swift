import SwiftUI

struct StreamYouTubeSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitVideoId(value: String) {
        stream.youTubeVideoId = value
        model.store()
        if stream.enabled {
            model.youTubeVideoIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: stream.youTubeVideoId!,
                    onSubmit: submitVideoId
                )
            } footer: {
                VStack(alignment: .leading) {
                    Text("Very experimental and very secret!")
                    Text("")
                    Text("The video id is the last part in your live streams URL.")
                }
            }
        }
        .navigationTitle("YouTube")
        .toolbar {
            SettingsToolbar()
        }
    }
}
