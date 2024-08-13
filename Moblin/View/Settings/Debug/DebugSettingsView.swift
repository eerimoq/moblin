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
        model.database.debug!.maximumLogLines = min(max(1, lines), 100_000)
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView(
                    log: model.log,
                    formatLog: { model.formatLog(log: model.log) },
                    clearLog: { model.clearLog() }
                )) {
                    Text("Log")
                }
                Toggle(isOn: Binding(get: {
                    model.database.debug!.logLevel == .debug
                }, set: { value in
                    logger.debugEnabled = value
                    if value {
                        model.database.debug!.logLevel = .debug
                    } else {
                        model.database.debug!.logLevel = .error
                    }
                    model.store()
                })) {
                    Text("Debug logging")
                }
                TextEditNavigationView(
                    title: "Maximum log lines",
                    value: String(model.database.debug!.maximumLogLines!),
                    onSubmit: submitLogLines
                )
                NavigationLink(destination: DebugAudioSettingsView()) {
                    Text("Audio")
                }
                NavigationLink(destination: DebugVideoSettingsView()) {
                    Text("Video")
                }
                Toggle("Debug overlay", isOn: Binding(get: {
                    model.database.debug!.srtOverlay
                }, set: { value in
                    model.database.debug!.srtOverlay = value
                    model.store()
                }))
                Toggle("Let it snow", isOn: Binding(get: {
                    model.database.debug!.letItSnow!
                }, set: { value in
                    model.database.debug!.letItSnow = value
                    model.store()
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
                            model.database.debug!.cameraSwitchRemoveBlackish = cameraSwitchRemoveBlackish
                            model.store()
                        }
                    )
                    Text("\(formatOneDecimal(value: cameraSwitchRemoveBlackish)) s")
                        .frame(width: 40)
                }
                Toggle("Blur scene switch", isOn: Binding(get: {
                    model.database.debug!.blurSceneSwitch!
                }, set: { value in
                    model.database.debug!.blurSceneSwitch = value
                    model.setBlurSceneSwitch()
                    model.store()
                }))
                Toggle("Global tone mapping", isOn: Binding(get: {
                    model.getGlobalToneMappingOn()
                }, set: { value in
                    model.setGlobalToneMapping(on: value)
                }))
                Toggle("MetalPetal filters", isOn: Binding(get: {
                    model.database.debug!.metalPetalFilters!
                }, set: { value in
                    model.database.debug!.metalPetalFilters = value
                    model.setMetalPetalFilters()
                    model.store()
                }))
                Toggle("Higher data rate limit", isOn: Binding(get: {
                    model.database.debug!.higherDataRateLimit!
                }, set: { value in
                    model.database.debug!.higherDataRateLimit = value
                    model.store()
                    model.setHigherDataRateLimit()
                }))
                Toggle("Use audio for timestamps", isOn: Binding(get: {
                    model.database.debug!.useAudioForTimestamps!
                }, set: { value in
                    model.database.debug!.useAudioForTimestamps = value
                    model.store()
                    model.setUseAudioForTimestamps()
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
                            model.database.debug!.maxMapPitch = maxMapPitch
                            model.setMapPitch()
                        }
                    )
                    Text(String(Int(maxMapPitch)))
                        .frame(width: 40)
                }
            } header: {
                Text("Experimental")
            }
        }
        .navigationTitle("Debug")
        .toolbar {
            SettingsToolbar()
        }
    }
}
