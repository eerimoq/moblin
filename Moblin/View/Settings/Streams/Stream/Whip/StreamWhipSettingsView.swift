import SwiftUI

struct StreamWhipSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    stream.whip.adaptiveBitrateEnabled
                }, set: { value in
                    stream.whip.adaptiveBitrateEnabled = value
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
            }
        }
        .navigationTitle("WHIP")
    }
}
