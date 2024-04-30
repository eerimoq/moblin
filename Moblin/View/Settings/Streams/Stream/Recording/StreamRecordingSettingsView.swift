import SwiftUI

struct StreamRecordingSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private func onVideoCodecChange(codec: String) {
        stream.recording!.videoCodec = SettingsStreamCodec(rawValue: codec)!
        model.store()
    }

    private func submitVideoBitrateChange(value: String) {
        guard var bitrate = Float(value) else {
            return
        }
        bitrate = max(bitrate, 0)
        bitrate = min(bitrate, 50)
        stream.recording!.videoBitrate = bitrateFromMbps(bitrate: bitrate)
        model.store()
    }

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0 && interval <= 10 else {
            return
        }
        stream.recording!.maxKeyFrameInterval = interval
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(title: String(localized: "Video codec"),
                                                             onChange: onVideoCodecChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(values: codecs),
                                                             selectedId: stream.recording!.videoCodec
                                                                 .rawValue))
                {
                    TextItemView(
                        name: String(localized: "Video codec"),
                        value: stream.recording!.videoCodec.rawValue
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Video bitrate"),
                    value: String(bitrateToMbps(bitrate: stream.recording!.videoBitrate)),
                    onSubmit: submitVideoBitrateChange,
                    footer: Text("Up to 50 Mbps. Set to 0 for automatic."),
                    keyboardType: .numbersAndPunctuation
                )) {
                    TextItemView(
                        name: String(localized: "Video bitrate"),
                        value: formatBytesPerSecond(speed: Int64(stream.recording!.videoBitrate))
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Key frame interval"),
                    value: String(stream.recording!.maxKeyFrameInterval),
                    onSubmit: submitMaxKeyFrameInterval,
                    footer: Text("Maximum key frame interval in seconds. Set to 0 for automatic."),
                    keyboardType: .numbersAndPunctuation
                )) {
                    TextItemView(
                        name: String(localized: "Key frame interval"),
                        value: "\(stream.recording!.maxKeyFrameInterval) s"
                    )
                }
                .disabled(stream.enabled && model.isRecording)
                Toggle("Auto start recording when live", isOn: Binding(get: {
                    stream.recording!.autoStartRecording!
                }, set: { value in
                    stream.recording!.autoStartRecording! = value
                    model.store()
                }))
                Toggle("Auto stop recording when offline", isOn: Binding(get: {
                    stream.recording!.autoStopRecording!
                }, set: { value in
                    stream.recording!.autoStopRecording! = value
                    model.store()
                }))
                Toggle("Stop recording when offline", isOn: Binding(get: {
                    stream.recording!.autoStopRecording!
                }, set: { value in
                    stream.recording!.autoStopRecording! = value
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
