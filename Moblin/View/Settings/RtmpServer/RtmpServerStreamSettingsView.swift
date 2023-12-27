import SwiftUI

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsRtmpServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.store()
    }

    private func submitStreamKey(value: String) {
        stream.streamKey = value.trim()
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(
                title: String(localized: "Name"),
                value: stream.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: stream.name)
            }
            NavigationLink(destination: TextEditView(
                title: String(localized: "Stream key"),
                value: stream.streamKey,
                onSubmit: submitStreamKey
            )) {
                TextItemView(name: String(localized: "Stream key"), value: stream.streamKey)
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
