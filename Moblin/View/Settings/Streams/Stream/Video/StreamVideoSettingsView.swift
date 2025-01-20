import SwiftUI

private struct StreamTimecodesSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TextEditView(title: String(localized: "NTP pool address"), value: stream.ntpPoolAddress!) {
                        stream.ntpPoolAddress = $0
                        if stream.enabled {
                            model.reloadNtpClient()
                            model.reloadSrtlaServer()
                        }
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "NTP pool address"),
                        value: stream.ntpPoolAddress!
                    )
                }
                .disabled(stream.codec != .h265hevc || (stream.enabled && model.isLive))
            }
        }
        .navigationTitle("Timecodes")
    }
}

struct StreamVideoSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var codec: String
    @State var bitrate: UInt32

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

    private func onBitrateChange(bitrate: UInt32) {
        self.bitrate = bitrate
        stream.bitrate = bitrate
        if stream.enabled {
            model.setStreamBitrate(stream: stream)
        }
    }

    private func onCodecChange(codec: String) {
        self.codec = codec
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
                            Text($0.shortString())
                                .tag($0.rawValue)
                        }
                    }
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
            }
            Section {
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
            } footer: {
                Text("Lower FPS generally gives brighter image in low light conditions.")
            }
            if #available(iOS 18, *) {
                Section {
                    Toggle("Low light boost (LLB)", isOn: Binding(get: {
                        stream.autoFps!
                    }, set: { value in
                        stream.autoFps = value
                        model.storeAndReloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && (model.isLive || model.isRecording))
                } footer: {
                    Text("""
                    Enable low light boost to make builtin cameras automatically \
                    lower the selected FPS for brighter image when dark (if supported).
                    """)
                }
            }
            if model.database.showAllSettings! {
                Section {
                    HStack {
                        Text("Codec")
                        Spacer()
                        Picker("", selection: Binding(get: {
                            codec
                        }, set: onCodecChange)) {
                            ForEach(codecs, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    .disabled(stream.enabled && model.isLive)
                } footer: {
                    Text("""
                    H.265/HEVC generally reuqires less bandwidth for same image quality. RTMP \
                    generally only supports H.264/AVC.
                    """)
                }
                Section {
                    HStack {
                        Text("Bitrate")
                        Spacer()
                        Picker("", selection: Binding(get: {
                            bitrate
                        }, set: onBitrateChange)) {
                            ForEach(model.database.bitratePresets) { preset in
                                Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                                    .tag(preset.bitrate)
                            }
                        }
                    }
                } footer: {
                    Text("About 5-8 Mbps is usually enough for decent image quality.")
                }
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Key frame interval"),
                            value: String(stream.maxKeyFrameInterval!),
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
                Section {
                    Toggle("Adaptive resolution", isOn: Binding(get: {
                        stream.adaptiveEncoderResolution!
                    }, set: { value in
                        stream.adaptiveEncoderResolution = value
                        model.storeAndReloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && model.isLive)
                } footer: {
                    Text("""
                    Automatically lower resolution when the available bandwidth is \
                    low. Generally gives better image quality at low (<750 Kbps) bitrates.
                    """)
                }
                if model.database.debug.timecodesEnabled! {
                    Section {
                        NavigationLink {
                            StreamTimecodesSettingsView(stream: stream)
                        } label: {
                            Toggle("Timecodes", isOn: Binding(get: {
                                stream.timecodesEnabled!
                            }, set: { value in
                                stream.timecodesEnabled = value
                                if stream.enabled {
                                    model.reloadNtpClient()
                                    model.reloadSrtlaServer()
                                }
                            }))
                            .disabled(stream.codec != .h265hevc || (stream.enabled && model.isLive))
                        }
                    } footer: {
                        Text("""
                        Synchronize multiple streams on your server using timecodes. \
                        Timecodes are in UTC and requires H.265/HEVC codec.
                        """)
                    }
                }
            }
        }
        .navigationTitle("Video")
    }
}
