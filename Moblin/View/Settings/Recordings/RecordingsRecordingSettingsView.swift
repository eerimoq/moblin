import AVFoundation
import SwiftUI

private class Mp4Converter {
    private var session: AVAssetExportSession?

    func start(fmp4Url: URL, onCompleted: @escaping (String) -> Void) {
        session = AVAssetExportSession(asset: AVURLAsset(url: fmp4Url, options: nil),
                                       presetName: AVAssetExportPresetPassthrough)
        guard let session else {
            return
        }
        let mp4Url = fmp4Url.appendingPathExtension("new")
        mp4Url.remove()
        session.outputURL = mp4Url
        session.outputFileType = .mp4
        session.exportAsynchronously {
            switch session.status {
            case .failed:
                onCompleted("Convertion failed: \(session.error ?? "???")")
            case .cancelled:
                onCompleted("Convertion cancelled")
            case .completed:
                let tempUrl = fmp4Url.appendingPathExtension("old")
                do {
                    try FileManager.default.moveItem(at: fmp4Url, to: tempUrl)
                    try FileManager.default.moveItem(at: mp4Url, to: fmp4Url)
                    tempUrl.remove()
                    onCompleted("Successfully converted")
                } catch {
                    onCompleted("Convertion failed: \(error)")
                }
            default:
                onCompleted("Convertion failed")
            }
        }
    }

    func stop() {
        session?.cancelExport()
        session = nil
    }
}

struct RecordingsRecordingSettingsView: View {
    let model: Model
    @ObservedObject var recording: Recording
    @State var image: UIImage?
    @State var convertToMp4Text: String? = "Convert to MP4"
    @State private var mp4Converter = Mp4Converter()

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
                            if let recording = recording.settings.recording {
                                TextValueView(
                                    name: String(localized: "Video codec"),
                                    value: recording.videoCodec.rawValue
                                )
                                TextValueView(
                                    name: String(localized: "Video bitrate"),
                                    value: recording.videoBitrateString()
                                )
                                TextValueView(
                                    name: String(localized: "Key frame interval"),
                                    value: recording.maxKeyFrameIntervalString()
                                )
                            }
                        }
                        TextValueView(
                            name: String(localized: "Audio codec"),
                            value: recording.settings.audioCodecString()
                        )
                        if let recording = recording.settings.recording {
                            TextValueView(
                                name: String(localized: "Audio bitrate"),
                                value: recording.audioBitrateString()
                            )
                        }
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
                    Section {
                        Button {
                            if let url = recording.url() {
                                convertToMp4Text = nil
                                mp4Converter.start(fmp4Url: url) {
                                    convertToMp4Text = $0
                                }
                            }
                        } label: {
                            HCenter {
                                if let convertToMp4Text {
                                    Text(convertToMp4Text)
                                } else {
                                    ProgressView()
                                    Text("Converting...")
                                }
                            }
                        }
                        .disabled(convertToMp4Text == nil)
                    }
                }
            }
            .navigationTitle("Recording")
            .onDisappear {
                mp4Converter.stop()
            }
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
