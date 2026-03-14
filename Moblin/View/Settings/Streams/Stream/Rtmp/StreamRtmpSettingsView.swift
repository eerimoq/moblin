import SwiftUI

struct StreamRtmpSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    stream.rtmp.adaptiveBitrateEnabled
                }, set: { value in
                    stream.rtmp.adaptiveBitrateEnabled = value
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                .disabledWhenLiveStreaming(stream: stream, model: model)
            }
        }
        .navigationTitle("RTMP")
    }
}
