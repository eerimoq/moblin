import SwiftUI

struct StreamReplaySettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream
    @ObservedObject var replay: SettingsStreamReplay

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $replay.enabled)
                    .onChange(of: replay.enabled) { _ in
                        if stream.enabled {
                            model.streamReplayEnabledUpdated()
                        }
                    }
                Toggle("Fade transition", isOn: $replay.fade)
            }
        }
        .navigationTitle("Replay")
    }
}
