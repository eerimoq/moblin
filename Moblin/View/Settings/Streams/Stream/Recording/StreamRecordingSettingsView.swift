import SwiftUI

struct StreamRecordingSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private var recording: SettingsStreamRecording {
        return stream.recording!
    }

    private func onVideoCodecChange(codec: String) {
        recording.videoCodec = SettingsStreamCodec(rawValue: codec)!
        model.store()
    }

    private func submitVideoBitrateChange(value: String) {
        guard var bitrate = Float(value) else {
            return
        }
        bitrate = max(bitrate, 0)
        bitrate = min(bitrate, 50)
        recording.videoBitrate = bitrateFromMbps(bitrate: bitrate)
        model.store()
    }

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0 && interval <= 10 else {
            return
        }
        recording.maxKeyFrameInterval = interval
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Video codec"),
                    onChange: onVideoCodecChange,
                    items: InlinePickerItem
                        .fromStrings(values: codecs),
                    selectedId: recording.videoCodec.rawValue
                )) {
                    TextItemView(
                        name: String(localized: "Video codec"),
                        value: recording.videoCodec.rawValue
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Video bitrate"),
                    value: String(bitrateToMbps(bitrate: recording.videoBitrate)),
                    onSubmit: submitVideoBitrateChange,
                    footer: Text("Up to 50 Mbps. Set to 0 for automatic."),
                    keyboardType: .numbersAndPunctuation
                )) {
                    TextItemView(
                        name: String(localized: "Video bitrate"),
                        value: formatBytesPerSecond(speed: Int64(recording.videoBitrate))
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Key frame interval"),
                    value: String(recording.maxKeyFrameInterval),
                    onSubmit: submitMaxKeyFrameInterval,
                    footer: Text("Maximum key frame interval in seconds. Set to 0 for automatic."),
                    keyboardType: .numbersAndPunctuation
                )) {
                    TextItemView(
                        name: String(localized: "Key frame interval"),
                        value: "\(recording.maxKeyFrameInterval) s"
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink(destination: StreamRecordingAudioSettingsView(
                    stream: stream,
                    bitrate: Float(recording.audioBitrate! / 1000)
                )) {
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
                    model.store()
                }))
                Toggle("Auto stop recording when ending stream", isOn: Binding(get: {
                    recording.autoStopRecording!
                }, set: { value in
                    recording.autoStopRecording = value
                    model.store()
                }))
            }
            footer: {
                Text("Resolution and FPS are same as for live stream.")
            }
        }
        .navigationTitle("Recording")
        .toolbar {
            SettingsToolbar()
        }
    }
}
