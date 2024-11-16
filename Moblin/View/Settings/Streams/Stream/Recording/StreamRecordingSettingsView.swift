import SwiftUI

struct StreamRecordingSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var videoCodec: String

    private var recording: SettingsStreamRecording {
        return stream.recording!
    }

    private func onVideoCodecChange(codec: String) {
        videoCodec = codec
        recording.videoCodec = SettingsStreamCodec(rawValue: codec)!
    }

    private func submitVideoBitrateChange(value: String) {
        guard var bitrate = Float(value) else {
            return
        }
        bitrate = max(bitrate, 0)
        bitrate = min(bitrate, 50)
        recording.videoBitrate = bitrateFromMbps(bitrate: bitrate)
    }

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0 && interval <= 10 else {
            return
        }
        recording.maxKeyFrameInterval = interval
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Video codec")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        videoCodec
                    }, set: onVideoCodecChange)) {
                        ForEach(codecs, id: \.self) {
                            Text($0)
                        }
                    }
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Video bitrate"),
                        value: String(bitrateToMbps(bitrate: recording.videoBitrate)),
                        footers: [String(localized: "Up to 50 Mbps. Set to 0 for automatic.")],
                        keyboardType: .numbersAndPunctuation
                    ){
                        submitVideoBitrateChange(value: $0)
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "Video bitrate"),
                        value: formatBytesPerSecond(speed: Int64(recording.videoBitrate))
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Key frame interval"),
                        value: String(recording.maxKeyFrameInterval),
                        footers: [
                            String(
                                localized: "Maximum key frame interval in seconds. Set to 0 for automatic."
                            ),
                        ],
                        keyboardType: .numbersAndPunctuation
                    ) {
                        submitMaxKeyFrameInterval(value: $0)
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "Key frame interval"),
                        value: "\(recording.maxKeyFrameInterval) s"
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink {
                    StreamRecordingAudioSettingsView(
                        stream: stream,
                        bitrate: Float(recording.audioBitrate! / 1000)
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Audio bitrate"),
                        value: formatBytesPerSecond(speed: Int64(recording.audioBitrate!))
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                Toggle("Auto start recording when going live", isOn: Binding(get: {
                    recording.autoStartRecording!
                }, set: { value in
                    recording.autoStartRecording = value
                }))
                Toggle("Auto stop recording when ending stream", isOn: Binding(get: {
                    recording.autoStopRecording!
                }, set: { value in
                    recording.autoStopRecording = value
                }))
            }
            footer: {
                Text("Resolution and FPS are same as for live stream.")
            }
        }
        .navigationTitle("Recording")
    }
}
