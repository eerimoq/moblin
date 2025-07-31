import SwiftUI

struct RecordingsRecordingSettingsView: View {
    let model: Model
    @ObservedObject var recording: Recording
    @State var image: UIImage?

    var body: some View {
        NavigationLink {
            VStack {
                HStack {
                    Spacer()
                    if let shareUrl = recording.shareUrl() {
                        ShareLink(item: shareUrl)
                    }
                }
                Form {
                    Section {
                        HCenter {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "photo")
                            }
                        }
                    }
                    Section {
                        TextField("Description", text: $recording.description)
                            .autocorrectionDisabled()
                            .onChange(of: recording.description) { _ in
                                model.recordingsStorage.store()
                            }
                    }
                    Section {
                        TextValueView(
                            name: String(localized: "Start time"),
                            value: recording.startTime.formatted()
                        )
                        TextValueView(
                            name: String(localized: "Length"),
                            value: recording.length().formatWithSeconds()
                        )
                        TextValueView(name: String(localized: "Size"), value: recording.sizeString())
                    }
                    Section {
                        TextValueView(
                            name: String(localized: "Resolution"),
                            value: recording.settings.resolutionString()
                        )
                        TextValueView(name: String(localized: "FPS"), value: "\(recording.settings.fps)")
                        if recording.settings.recording == nil {
                            TextValueView(
                                name: String(localized: "Video codec"),
                                value: recording.settings.codecString()
                            )
                        } else {
                            TextValueView(
                                name: String(localized: "Video codec"),
                                value: recording.settings.recording!.videoCodec.rawValue
                            )
                            TextValueView(
                                name: String(localized: "Video bitrate"),
                                value: recording.settings.recording!.videoBitrateString()
                            )
                            TextValueView(
                                name: String(localized: "Key frame interval"),
                                value: recording.settings.recording!.maxKeyFrameIntervalString()
                            )
                        }
                        TextValueView(
                            name: String(localized: "Audio codec"),
                            value: recording.settings.audioCodecString()
                        )
                        TextValueView(
                            name: String(localized: "Audio bitrate"),
                            value: recording.settings.recording!.audioBitrateString()
                        )
                        if let recordingPath = recording.getRecordingPath() {
                            HStack {
                                Text("Recording path")
                                Spacer()
                                Text(recordingPath)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                        }
                    } header: {
                        Text("Settings")
                    }
                }
            }
            .navigationTitle("Recording")
        } label: {
            HStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90)
                } else {
                    Image(systemName: "photo")
                }
                VStack(alignment: .leading) {
                    Text(recording.startTime.formatted())
                    Text(recording.length().formatWithSeconds())
                    Text(recording.subTitle())
                        .font(.footnote)
                }
            }
        }
        .onAppear {
            if let url = recording.url() {
                createThumbnail(path: url) { image in
                    self.image = image
                }
            }
        }
    }
}
