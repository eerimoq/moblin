import SwiftUI
import WebKit

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @State var cameraSwitchRemoveBlackish: Float
    @State var dataRateLimitFactor: Float

    private func submitLogLines(value: String) {
        guard let lines = Int(value) else {
            return
        }
        model.database.debug.maximumLogLines = min(max(1, lines), 100_000)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    DebugLogSettingsView(
                        log: model.log,
                        formatLog: { model.formatLog(log: model.log) },
                        clearLog: { model.clearLog() }
                    )
                } label: {
                    Text("Log")
                }
                Toggle(isOn: Binding(get: {
                    model.database.debug.logLevel == .debug
                }, set: { value in
                    model.setDebugLogging(on: value)
                })) {
                    Text("Debug logging")
                }
                TextEditNavigationView(
                    title: "Maximum log lines",
                    value: String(model.database.debug.maximumLogLines!),
                    onSubmit: submitLogLines
                )
                Toggle("Debug overlay", isOn: Binding(get: {
                    model.database.debug.srtOverlay
                }, set: { value in
                    model.database.debug.srtOverlay = value
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
                            model.database.debug.cameraSwitchRemoveBlackish = cameraSwitchRemoveBlackish
                        }
                    )
                    Text("\(formatOneDecimal(cameraSwitchRemoveBlackish)) s")
                        .frame(width: 40)
                }
                Toggle("Bitrate drop fix", isOn: Binding(get: {
                    model.database.debug.bitrateDropFix!
                }, set: { value in
                    model.database.debug.bitrateDropFix = value
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
                            model.database.debug.dataRateLimitFactor = dataRateLimitFactor
                            model.setBitrateDropFix()
                        }
                    )
                    Text(formatOneDecimal(dataRateLimitFactor))
                        .frame(width: 40)
                }
                Toggle("Relaxed bitrate decrement after scene switch", isOn: Binding(get: {
                    model.database.debug.relaxedBitrate!
                }, set: { value in
                    model.database.debug.relaxedBitrate = value
                }))
                Toggle("Global tone mapping", isOn: Binding(get: {
                    model.getGlobalToneMappingOn()
                }, set: { value in
                    model.setGlobalToneMapping(on: value)
                }))
                Toggle("MetalPetal filters", isOn: Binding(get: {
                    model.database.debug.metalPetalFilters!
                }, set: { value in
                    model.database.debug.metalPetalFilters = value
                    model.setMetalPetalFilters()
                }))
                Toggle("Twitch rewards", isOn: Binding(get: {
                    model.database.debug.twitchRewards!
                }, set: { value in
                    model.database.debug.twitchRewards = value
                }))
                NavigationLink {
                    DebugHttpProxySettingsView()
                } label: {
                    Text("HTTP proxy")
                }
                Toggle("Pretty snapshot", isOn: Binding(get: {
                    model.database.debug.prettySnapshot!
                }, set: { value in
                    model.database.debug.prettySnapshot = value
                }))
                Toggle("Reliable chat", isOn: Binding(get: {
                    model.database.debug.reliableChat!
                }, set: { value in
                    model.database.debug.reliableChat = value
                }))
                Toggle("Timecodes", isOn: Binding(get: {
                    model.database.debug.timecodesEnabled!
                }, set: { value in
                    model.database.debug.timecodesEnabled = value
                    model.reloadNtpClient()
                    model.reloadSrtlaServer()
                }))
                Toggle("SRT(LA) batch send", isOn: Binding(get: {
                    model.database.debug.srtlaBatchSend!
                }, set: { value in
                    model.database.debug.srtlaBatchSend = value
                    model.setSrtlaBatchSend()
                }))
                Toggle("Camera controls", isOn: Binding(get: {
                    model.database.debug.cameraControlsEnabled!
                }, set: { value in
                    model.database.debug.cameraControlsEnabled = value
                    model.setCameraControlsEnabled()
                }))
            } header: {
                Text("Experimental")
            }
        }
        .navigationTitle("Debug")
    }
}
