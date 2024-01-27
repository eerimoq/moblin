import SwiftUI

struct RecordingsRecordingSettingsView: View {
    var recording: Recording
    var quickDone: (() -> Void)?

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
                }
                Section {
                    TextValueView(name: "Start time", value: recording.startTime.formatted())
                    TextValueView(name: "Length", value: recording.length().formatWithSeconds())
                    TextValueView(name: "Size", value: recording.sizeString())
                }
                Section {
                    TextValueView(name: "Resolution", value: recording.settings.resolutionString())
                    TextValueView(name: "FPS", value: "\(recording.settings.fps)")
                    if recording.settings.recording == nil {
                        TextValueView(name: "Video codec", value: recording.settings.codecString())
                    } else {
                        TextValueView(
                            name: "Video codec",
                            value: recording.settings.recording!.videoCodecString()
                        )
                        TextValueView(
                            name: "Video bitrate",
                            value: recording.settings.recording!.videoBitrateString()
                        )
                        TextValueView(
                            name: "Key frame interval",
                            value: recording.settings.recording!.maxKeyFrameIntervalString()
                        )
                    }
                    TextValueView(name: "Audio codec", value: recording.settings.audioCodecString())
                } header: {
                    Text("Settings")
                }
            }
        }
        .navigationTitle("Recording")
        .toolbar {
            SettingsToolbar(quickDone: quickDone)
        }
    }
}
