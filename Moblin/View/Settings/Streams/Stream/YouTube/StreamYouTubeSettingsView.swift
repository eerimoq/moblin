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
                Text("Very experimental and very secret!")
            }
        }
        .navigationTitle("YouTube")
        .toolbar {
            SettingsToolbar()
        }
    }
}
