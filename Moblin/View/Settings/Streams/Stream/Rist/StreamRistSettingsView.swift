import SwiftUI

struct StreamRistSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    stream.rist.adaptiveBitrateEnabled
                }, set: { value in
                    stream.rist.adaptiveBitrateEnabled = value
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
                Toggle("Bonding", isOn: Binding(get: {
                    stream.rist.bonding
                }, set: { value in
                    stream.rist.bonding = value
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
            }
        }
        .navigationTitle("RIST")
    }
}
