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
                HStack {
                    Text("Start time")
                    Spacer()
                    Text(recording.startTime.formatted())
                }
                HStack {
                    Text("Length")
                    Spacer()
                    Text(recording.length().format())
                }
            } header: {
                Text("About")
            }
            Section {
                HStack {
                    Text("Resolution")
                    Spacer()
                    Text(recording.settings.resolutionString())
                }
                HStack {
                    Text("FPS")
                    Spacer()
                    Text("\(recording.settings.fps)")
                }
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
