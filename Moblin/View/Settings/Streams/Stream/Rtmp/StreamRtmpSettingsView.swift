import SwiftUI

struct StreamRtmpSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    stream.rtmp!.adaptiveBitrateEnabled
                }, set: { value in
                    stream.rtmp!.adaptiveBitrateEnabled = value
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
            }
        }
        .navigationTitle("RTMP")
        .toolbar {
            SettingsToolbar()
        }
    }
}
