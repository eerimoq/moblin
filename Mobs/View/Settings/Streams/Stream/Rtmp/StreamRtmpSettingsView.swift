import SwiftUI

struct StreamRtmpSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream

    func submitUrl(value: String) {
        if makeRtmpUri(url: value) == "" {
            return
        }
        if makeRtmpStreamName(url: value) == "" {
            return
        }
        stream.rtmpUrl = value
        model.store()
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            NavigationLink(destination: SensitiveUrlEditView(value: stream.rtmpUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: stream.rtmpUrl, sensitive: true)
            }
        }
        .navigationTitle("RTMP")
    }
}
