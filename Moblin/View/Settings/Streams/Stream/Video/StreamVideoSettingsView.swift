import SwiftUI

struct StreamVideoSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private func onResolutionChange(resolution: String) {
        stream.resolution = SettingsStreamResolution(rawValue: resolution)!
        model.storeAndReloadStreamIfEnabled(stream: stream)
        model.resetSelectedScene(changeScene: false)
        model.updateOrientation()
    }

    private func onFpsChange(fps: String) {
        stream.fps = Int(fps)!
        model.storeAndReloadStreamIfEnabled(stream: stream)
        model.resetSelectedScene(changeScene: false)
        model.updateOrientation()
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
        model.updateOrientation()
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Resolution")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        stream.resolution.rawValue
                    }, set: onResolutionChange)) {
                        ForEach(resolutions, id: \.self) {
                            Text($0)
                        }
                    }
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
                HStack {
                    Text("FPS")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        String(stream.fps)
                    }, set: onFpsChange)) {
                        ForEach(fpss, id: \.self) {
                            Text($0)
                        }
                    }
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
                if model.database.showAllSettings! {
                    HStack {
                        Text("Codec")
                        Spacer()
                        Picker("", selection: Binding(get: {
                            stream.codec.rawValue
                        }, set: onCodecChange)) {
                            ForEach(codecs, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    .disabled(stream.enabled && model.isLive)
                    NavigationLink(destination: StreamVideoBitrateSettingsView(
                        stream: stream,
                        selection: stream.bitrate
                    )) {
                        TextItemView(
                            name: String(localized: "Bitrate"),
                            value: formatBytesPerSecond(speed: Int64(stream.bitrate))
                        )
                    }
                    NavigationLink(destination: TextEditView(
                        title: String(localized: "Key frame interval"),
                        value: String(stream.maxKeyFrameInterval!),
                        onSubmit: submitMaxKeyFrameInterval,
                        footers: [
                            String(
                                localized: "Maximum key frame interval in seconds. Set to 0 for automatic."
                            ),
                        ],
                        keyboardType: .numbersAndPunctuation
                    )) {
                        TextItemView(
                            name: String(localized: "Key frame interval"),
                            value: "\(stream.maxKeyFrameInterval!) s"
                        )
                    }
                    .disabled(stream.enabled && model.isLive)
                    Toggle("B-frames", isOn: Binding(get: {
                        stream.bFrames!
                    }, set: { value in
                        stream.bFrames = value
                        model.storeAndReloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && model.isLive)
                }
            }
        }
        .navigationTitle("Video")
        .toolbar {
            SettingsToolbar()
        }
    }
}
