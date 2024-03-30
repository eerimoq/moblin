import SwiftUI

struct StreamYouTubeSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitApiKey(value: String) {
        stream.youTubeApiKey = value
        model.store()
        if stream.enabled {
            model.youTubeApiKeyUpdated()
        }
    }

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
                    title: String(localized: "API key"),
                    value: stream.youTubeApiKey!,
                    onSubmit: submitApiKey
                )
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: stream.youTubeVideoId!,
                    onSubmit: submitVideoId
                )
            } footer: {
                VStack(alignment: .leading) {
                    Text("Very experimental and very secret!")
                    Text("")
                    Text("API key for YouTube Data API v3 is needed.")
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
