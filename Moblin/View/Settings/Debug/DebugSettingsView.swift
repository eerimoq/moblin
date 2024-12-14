import SwiftUI
import WebKit

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @State var cameraSwitchRemoveBlackish: Float
    @State var maxMapPitch: Double

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
                Toggle("Debug overlay", isOn: Binding(get: {
                    model.database.debug.srtOverlay
                }, set: { value in
                    model.database.debug.srtOverlay = value
                }))
            }
            Section {
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
                            ioVideoUnitIgnoreFramesAfterAttachSeconds = Double(cameraSwitchRemoveBlackish)
                            model.database.debug.cameraSwitchRemoveBlackish = cameraSwitchRemoveBlackish
                        }
                    )
                    Text("\(formatOneDecimal(cameraSwitchRemoveBlackish)) s")
                        .frame(width: 40)
                }
                Toggle("Blur scene switch", isOn: Binding(get: {
                    model.database.debug.blurSceneSwitch!
                }, set: { value in
                    model.database.debug.blurSceneSwitch = value
                    model.setBlurSceneSwitch()
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
                HStack {
                    Text("Max map pitch")
                    Slider(
                        value: $maxMapPitch,
                        in: 0.0 ... 85.0,
                        step: 1.0,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.debug.maxMapPitch = maxMapPitch
                            model.setMapPitch()
                        }
                    )
                    Text(String(Int(maxMapPitch)))
                        .frame(width: 40)
                }
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
            } header: {
                Text("Experimental")
            }
        }
        .navigationTitle("Debug")
    }
}
