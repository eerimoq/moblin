import SwiftUI
import WebKit

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug
    @State var cameraSwitchRemoveBlackish: Float
    @State var dataRateLimitFactor: Float
    @State var recordSegmentLength: Double
    @State var builtinAudioAndVideoDelay: Double

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
                Toggle("Debug overlay", isOn: Binding(get: {
                    debug.srtOverlay
                }, set: { value in
                    debug.srtOverlay = value
                }))
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
                        value: $cameraSwitchRemoveBlackish,
                        in: 0.0 ... 1.0,
                        step: 0.1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            debug.cameraSwitchRemoveBlackish = cameraSwitchRemoveBlackish
                        }
                    )
                    Text("\(formatOneDecimal(cameraSwitchRemoveBlackish)) s")
                        .frame(width: 40)
                }
                Toggle("Bitrate drop fix", isOn: Binding(get: {
                    debug.bitrateDropFix
                }, set: { value in
                    debug.bitrateDropFix = value
                    model.setBitrateDropFix()
                }))
                HStack {
                    Text("Data rate limit")
                    Slider(
                        value: $dataRateLimitFactor,
                        in: 1.2 ... 2.5,
                        step: 0.1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            debug.dataRateLimitFactor = dataRateLimitFactor
                            model.setBitrateDropFix()
                        }
                    )
                    Text(formatOneDecimal(dataRateLimitFactor))
                        .frame(width: 40)
                }
                Toggle("Relaxed bitrate decrement after scene switch", isOn: Binding(get: {
                    debug.relaxedBitrate
                }, set: { value in
                    debug.relaxedBitrate = value
                }))
                Toggle("Global tone mapping", isOn: Binding(get: {
                    model.getGlobalToneMappingOn()
                }, set: { value in
                    model.setGlobalToneMapping(on: value)
                }))
                Toggle("MetalPetal filters", isOn: Binding(get: {
                    debug.metalPetalFilters
                }, set: { value in
                    debug.metalPetalFilters = value
                    model.setMetalPetalFilters()
                }))
                Toggle("Twitch rewards", isOn: Binding(get: {
                    debug.twitchRewards
                }, set: { value in
                    debug.twitchRewards = value
                }))
                NavigationLink {
                    DebugHttpProxySettingsView()
                } label: {
                    Text("HTTP proxy")
                }
                Toggle("Reliable chat", isOn: Binding(get: {
                    debug.reliableChat
                }, set: { value in
                    debug.reliableChat = value
                }))
                Toggle("Timecodes", isOn: Binding(get: {
                    debug.timecodesEnabled
                }, set: { value in
                    debug.timecodesEnabled = value
                    model.reloadNtpClient()
                    model.reloadSrtlaServer()
                }))
                Toggle("SRT(LA) batch send", isOn: Binding(get: {
                    debug.srtlaBatchSendEnabled
                }, set: { value in
                    debug.srtlaBatchSendEnabled = value
                    model.setSrtlaBatchSend()
                }))
                NavigationLink {
                    DjiGimbalDevicesSettingsView()
                } label: {
                    IconAndTextView(image: "appletvremote.gen1", text: String(localized: "DJI gimbals"))
                }
                VStack(alignment: .leading) {
                    Text("Builtin audio and video delay")
                    HStack {
                        Slider(
                            value: $builtinAudioAndVideoDelay,
                            in: 0.0 ... 4.0,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                debug.builtinAudioAndVideoDelay = builtinAudioAndVideoDelay
                            }
                        )
                        Text(formatTwoDecimals(builtinAudioAndVideoDelay))
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
