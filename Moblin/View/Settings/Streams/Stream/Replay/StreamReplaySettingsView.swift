import SwiftUI

struct StreamReplaySettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    stream.replay.enabled
                }, set: { value in
                    stream.replay.enabled = value
                    if stream.enabled {
                        model.streamReplayEnabledUpdated()
                        model.objectWillChange.send()
                    }
                }))
                Toggle("Fade transition", isOn: Binding(get: {
                    stream.replay.fade!
                }, set: { value in
                    stream.replay.fade = value
                }))
            }
        }
        .navigationTitle("Replay")
    }
}
