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
                Toggle("Debug overlay", isOn: $debug.debugOverlay)
                    .onChange(of: debug.debugOverlay) { _ in
                        model.updateDebugOverlay()
                    }
            }
            Section {
                NavigationLink {
                    DebugAudioSettingsView(debug: debug)
                } label: {
                    Text("Audio")
                }
                NavigationLink {
                    DebugVideoSettingsView(debug: debug)
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
                NavigationLink {
                    DjiGimbalDevicesSettingsView()
                } label: {
                    Label("DJI gimbals", systemImage: "appletvremote.gen1")
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
                // Toggle("Auto low power mode", isOn: $debug.autoLowPowerMode)
                //     .onChange(of: debug.autoLowPowerMode) { _ in
                //         if model.statusOther.thermalState == .critical {
                //             model.startLowPowerMode()
                //         } else {
                //             model.stopLowPowerMode()
                //         }
                //     }
                Toggle("New SRT", isOn: $debug.newSrt)
                    .onChange(of: debug.newSrt) { _ in
                        model.reloadStream()
                        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                    }
                Toggle("RTSP client", isOn: $debug.rtspClient)
                    .onChange(of: debug.rtspClient) { _ in
                        model.reloadRtspClient()
                    }
            } header: {
                Text("Experimental")
            }
            #if canImport(DeviceDiscoveryUI)
                if #available(iOS 26.0, *) {
                    Section {
                        HCenter {
                            WiFiAwarePublisherView()
                        }
                    }
                    Section {
                        HCenter {
                            WiFiAwareSubscriberView()
                        }
                    }
                }
            #endif
        }
        .navigationTitle("Debug")
    }
}
