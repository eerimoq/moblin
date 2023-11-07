import SwiftUI

struct StreamYouTubeSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitApiKey(value: String) {
        stream.youTubeApiKey = value
        model.store()
    }

    func submitChatLiveId(value: String) {
        stream.youTubeLiveChatId = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: "API Key",
                    value: stream.youTubeApiKey!,
                    onSubmit: submitApiKey
                )) {
                    TextItemView(name: "API Key", value: stream.youTubeApiKey!)
                }
                NavigationLink(destination: TextEditView(
                    title: "Live chat id",
                    value: stream.youTubeLiveChatId!,
                    onSubmit: submitChatLiveId
                )) {
                    TextItemView(name: "Live chat id", value: stream.youTubeLiveChatId!)
                }
            } footer: {
                Text("Very experimental and very secret!")
            }
        }
        .navigationTitle("YouTube")
    }
}
