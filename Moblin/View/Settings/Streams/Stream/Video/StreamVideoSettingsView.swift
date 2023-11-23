import SwiftUI

struct StreamVideoSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private func onResolutionChange(resolution: String) {
        stream.resolution = SettingsStreamResolution(rawValue: resolution)!
        model.storeAndReloadStreamIfEnabled(stream: stream)
    }

    private func onFpsChange(fps: String) {
        stream.fps = Int(fps)!
        model.storeAndReloadStreamIfEnabled(stream: stream)
    }

    private func onCodecChange(codec: String) {
        stream.codec = SettingsStreamCodec(rawValue: codec)!
        model.storeAndReloadStreamIfEnabled(stream: stream)
    }

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0 && interval <= 10 else {
            return
        }
        stream.maxKeyFrameInterval = interval
        model.storeAndReloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(title: "Resolution",
                                                             onChange: onResolutionChange,
                                                             items: resolutions,
                                                             selected: stream.resolution
                                                                 .rawValue))
                {
                    TextItemView(name: "Resolution", value: stream.resolution.rawValue)
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: InlinePickerView(title: "FPS",
                                                             onChange: onFpsChange,
                                                             items: fpss,
                                                             selected: String(stream
                                                                 .fps)))
                {
                    TextItemView(name: "FPS", value: String(stream.fps))
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: InlinePickerView(title: "Codec",
                                                             onChange: onCodecChange,
                                                             items: codecs,
                                                             selected: stream.codec
                                                                 .rawValue))
                {
                    TextItemView(name: "Codec", value: stream.codec.rawValue)
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: StreamVideoBitrateSettingsView(
                    stream: stream,
                    selection: stream.bitrate
                )) {
                    TextItemView(
                        name: "Bitrate",
                        value: formatBytesPerSecond(speed: Int64(stream.bitrate))
                    )
                }
                NavigationLink(destination: TextEditView(
                    title: "Key frame interval",
                    value: String(stream.maxKeyFrameInterval!),
                    onSubmit: submitMaxKeyFrameInterval,
                    footer: Text("Maximum key frame interval in seconds. Set to 0 for automatic.")
                )) {
                    TextItemView(name: "Key frame interval", value: String(stream.maxKeyFrameInterval!))
                }
                if logger.debugEnabled {
                    NavigationLink(
                        destination: StreamVideoCaptureSessionPresetSettingsView(
                            stream: stream,
                            selection: stream.captureSessionPreset.rawValue
                        )
                    ) {
                        Toggle(isOn: Binding(get: {
                            stream.captureSessionPresetEnabled
                        }, set: { value in
                            stream.captureSessionPresetEnabled = value
                            model.storeAndReloadStreamIfEnabled(stream: stream)
                        })) {
                            TextItemView(
                                name: "Preset",
                                value: stream.captureSessionPreset.rawValue
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Video")
        .toolbar {
            SettingsToolbar()
        }
    }
}
