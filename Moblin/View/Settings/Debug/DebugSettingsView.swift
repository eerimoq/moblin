import SwiftUI
import WebKit

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug

    private func submitLogLines(value: String) {
        guard let lines = Int(value) else {
            return
        }
        debug.maximumLogLines = min(max(1, lines), 100_000)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    DebugLogSettingsView(log: model.log, clearLog: { model.clearLog() })
                } label: {
                    Text("Log")
                }
                Toggle(isOn: Binding(get: {
                    debug.logLevel == .debug
                }, set: { value in
                    model.setDebugLogging(on: value)
                })) {
                    Text("Debug logging")
                }
                TextEditNavigationView(
                    title: "Maximum log lines",
                    value: String(debug.maximumLogLines),
                    onSubmit: submitLogLines
                )
                Toggle("Debug overlay", isOn: $debug.srtOverlay)
            }
            Section {
                NavigationLink {
                    DebugAudioSettingsView()
                } label: {
                    Text("Audio")
                }
                NavigationLink {
                    DebugVideoSettingsView()
                } label: {
                    Text("Video")
                }
                HStack {
                    Text("Video blackish")
                    Slider(
                        value: $debug.cameraSwitchRemoveBlackish,
                        in: 0.0 ... 1.0,
                        step: 0.1
                    )
                    Text("\(formatOneDecimal(debug.cameraSwitchRemoveBlackish)) s")
                        .frame(width: 40)
                }
                Toggle("Bitrate drop fix", isOn: $debug.bitrateDropFix)
                    .onChange(of: debug.bitrateDropFix) { _ in
                        model.setBitrateDropFix()
                    }
                HStack {
                    Text("Data rate limit")
                    Slider(
                        value: $debug.dataRateLimitFactor,
                        in: 1.2 ... 2.5,
                        step: 0.1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setBitrateDropFix()
                        }
                    )
                    Text(formatOneDecimal(debug.dataRateLimitFactor))
                        .frame(width: 40)
                }
                Toggle("Relaxed bitrate decrement after scene switch", isOn: $debug.relaxedBitrate)
                Toggle("Global tone mapping", isOn: Binding(get: {
                    model.getGlobalToneMappingOn()
                }, set: { value in
                    model.setGlobalToneMapping(on: value)
                }))
                Toggle("MetalPetal filters", isOn: $debug.metalPetalFilters)
                    .onChange(of: debug.metalPetalFilters) { _ in
                        model.setMetalPetalFilters()
                    }
                Toggle("Twitch rewards", isOn: $debug.twitchRewards)
                NavigationLink {
                    DebugHttpProxySettingsView()
                } label: {
                    Text("HTTP proxy")
                }
                Toggle("Reliable chat", isOn: $debug.reliableChat)
                Toggle("Timecodes", isOn: $debug.timecodesEnabled)
                    .onChange(of: debug.timecodesEnabled) { _ in
                        model.reloadNtpClient()
                        model.reloadSrtlaServer()
                    }
                Toggle("SRT(LA) batch send", isOn: $debug.srtlaBatchSendEnabled)
                    .onChange(of: debug.srtlaBatchSendEnabled) { _ in
                        model.setSrtlaBatchSend()
                    }
                NavigationLink {
                    DjiGimbalDevicesSettingsView()
                } label: {
                    IconAndTextView(image: "appletvremote.gen1", text: String(localized: "DJI gimbals"))
                }
                VStack(alignment: .leading) {
                    Text("Builtin audio and video delay")
                    HStack {
                        Slider(
                            value: $debug.builtinAudioAndVideoDelay,
                            in: 0.0 ... 4.0,
                            step: 0.01
                        )
                        Text(formatTwoDecimals(debug.builtinAudioAndVideoDelay))
                            .frame(width: 40)
                    }
                }
            } header: {
                Text("Experimental")
            }
        }
        .navigationTitle("Debug")
    }
}
