import SwiftUI

struct RecordingsRecordingSettingsView: View {
    var recording: Recording

    var body: some View {
        VStack {
            HStack {
                Spacer()
                ShareLink(item: recording.url())
            }
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let image = createThumbnail(path: recording.url()) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "photo")
                        }
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
                    TextValueView(name: "Video codec", value: recording.settings.codecString())
                    TextValueView(name: "Audio codec", value: recording.settings.audioCodecString())
                } header: {
                    Text("Settings")
                }
            }
        }
        .navigationTitle("Recording")
        .toolbar {
            SettingsToolbar()
        }
    }
}
