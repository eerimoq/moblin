import SwiftUI

struct RecordingsRecordingSettingsView: View {
    var recording: Recording

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(systemName: "photo")
                        .font(.title)
                    Spacer()
                }
            } header: {
                Text("Thumbnail")
            }
            Section {
                TextValueView(name: "Start time", value: recording.startTime.formatted())
                TextValueView(name: "Length", value: recording.length().formatWithSeconds())
                TextValueView(name: "Size", value: recording.sizeString())
            } header: {
                Text("About")
            }
            Section {
                TextValueView(name: "Resolution", value: recording.settings.resolutionString())
                TextValueView(name: "FPS", value: "\(recording.settings.fps)")
            } header: {
                Text("Settings")
            }
        }
        .navigationTitle("Recording")
        .toolbar {
            SettingsToolbar()
        }
    }
}
