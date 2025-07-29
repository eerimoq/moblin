import SwiftUI

private struct StreamTimecodesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TextEditView(title: String(localized: "NTP pool address"), value: stream.ntpPoolAddress) {
                        stream.ntpPoolAddress = $0
                        if stream.enabled {
                            model.reloadNtpClient()
                            model.reloadSrtlaServer()
                        }
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "NTP pool address"),
                        value: stream.ntpPoolAddress
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
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0, interval <= 10 else {
            return
        }
        stream.maxKeyFrameInterval = interval
        model.reloadStreamIfEnabled(stream: stream)
    }

    private func areTimecodesDisabled() -> Bool {
        if ![.srt, .rist].contains(stream.getProtocol()) {
            return true
        }
        if stream.codec != .h265hevc {
            return true
        }
        return stream.enabled && model.isLive
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Resolution")
                    Spacer()
                    Picker("", selection: $stream.resolution) {
                        ForEach(resolutions, id: \.self) {
                            Text($0.shortString())
                        }
                    }
                }
                .onChange(of: stream.resolution) { _ in
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
            }
            Section {
                HStack {
                    Text("FPS")
                    Spacer()
                    Picker("", selection: $stream.fps) {
                        ForEach(fpss, id: \.self) {
                            Text(String($0))
                        }
                    }
                }
                .onChange(of: stream.fps) { _ in
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
            } footer: {
                Text("Lower FPS generally gives brighter image in low light conditions.")
            }
            if #available(iOS 18, *) {
                Section {
                    Toggle("Low light boost (LLB)", isOn: $stream.autoFps)
                        .onChange(of: stream.autoFps) { _ in
                            model.setStreamFps()
                        }
                } footer: {
                    Text("""
                    Enable low light boost to make builtin cameras automatically \
                    lower the selected FPS for brighter image when dark (if supported).
                    """)
                }
            }
            if database.showAllSettings {
                Section {
                    HStack {
                        Text("Codec")
                        Spacer()
                        Picker("", selection: $stream.codec) {
                            ForEach(SettingsStreamCodec.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                    }
                    .onChange(of: stream.codec) { _ in
                        model.reloadStreamIfEnabled(stream: stream)
                    }
                    .disabled(stream.enabled && model.isLive)
                } footer: {
                    Text("""
                    H.265/HEVC generally requires less bandwidth for same image quality. RTMP \
                    generally only supports H.264/AVC.
                    """)
                }
                Section {
                    Label {
                        HStack {
                            Text("Bitrate")
                            Spacer()
                            Picker("", selection: $stream.bitrate) {
                                ForEach(database.bitratePresets) { preset in
                                    Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                                        .tag(preset.bitrate)
                                }
                            }
                            .onChange(of: stream.bitrate) { _ in
                                if stream.enabled {
                                    model.setStreamBitrate(stream: stream)
                                }
                            }
                        }
                    } icon: {
                        Image(systemName: "speedometer")
                    }
                    NavigationLink {
                        BitratePresetsSettingsView(database: model.database)
                    } label: {
                        Text("Bitrate presets")
                    }
                } footer: {
                    Text("About 5-8 Mbps is usually enough for decent image quality.")
                }
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Key frame interval"),
                            value: String(stream.maxKeyFrameInterval),
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
                            value: "\(stream.maxKeyFrameInterval) s"
                        )
                    }
                    .disabled(stream.enabled && model.isLive)
                    Toggle("B-frames", isOn: $stream.bFrames)
                        .onChange(of: stream.bFrames) { _ in
                            model.reloadStreamIfEnabled(stream: stream)
                        }
                        .disabled(stream.enabled && model.isLive)
                }
                Section {
                    Toggle("Adaptive resolution", isOn: $stream.adaptiveEncoderResolution)
                        .onChange(of: stream.adaptiveEncoderResolution) { _ in
                            model.reloadStreamIfEnabled(stream: stream)
                        }
                        .disabled(stream.enabled && model.isLive)
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Automatically lower resolution when the available bandwidth is \
                        low. Generally gives better image quality at low (<750 Kbps) bitrates.
                        """)
                        Text("")
                        Text("""
                        Warning: OBS typically requires hardware decoding not to crash when enabled.
                        """)
                    }
                }
                Section {
                    NavigationLink {
                        StreamTimecodesSettingsView(stream: stream)
                    } label: {
                        Toggle("Timecodes", isOn: $stream.timecodesEnabled)
                            .onChange(of: stream.timecodesEnabled) { _ in
                                if stream.enabled {
                                    model.reloadNtpClient()
                                    model.reloadSrtlaServer()
                                }
                            }
                            .disabled(areTimecodesDisabled())
                    }
                } footer: {
                    Text("""
                    Synchronize multiple streams on your server using timecodes. \
                    Timecodes are in UTC and requires H.265/HEVC codec and SRT(LA) or \
                    RIST.
                    """)
                }
            }
        }
        .navigationTitle("Video")
    }
}
