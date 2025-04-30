import SwiftUI

struct StreamReplaySettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    stream.replay!.enabled
                }, set: { value in
                    stream.replay!.enabled = value
                    if stream.enabled {
                        model.streamReplayEnabledUpdated()
                    }
                }))
            }
        }
        .navigationTitle("Replay")
    }
}
