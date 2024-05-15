import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @State var cameraSwitchRemoveBlackish: Float

    private func onLogLevelChange(level: String) {
        guard let level = SettingsLogLevel(rawValue: level) else {
            return
        }
        logger.debugEnabled = level == .debug
        model.database.debug!.logLevel = level
        model.store()
    }

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
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Log level"),
                    onChange: onLogLevelChange,
                    items: InlinePickerItem.fromStrings(values: logLevels),
                    selectedId: model.database.debug!.logLevel.rawValue
                )) {
                    TextItemView(
                        name: String(localized: "Log level"),
                        value: model.database.debug!.logLevel.rawValue
                    )
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
                NavigationLink(destination: DebugBeautyFilterSettingsView(
                    brightness: model.database.debug!.beautyFilterSettings!.brightness,
                    contrast: model.database.debug!.beautyFilterSettings!.contrast,
                    saturation: model.database.debug!.beautyFilterSettings!.saturation
                )) {
                    Text("Beauty filter")
                }
                Toggle("MetalPetal filters", isOn: Binding(get: {
                    model.database.debug!.metalPetalFilters!
                }, set: { value in
                    model.database.debug!.metalPetalFilters = value
                    model.setMetalPetalFilters()
                    model.store()
                }))
                Toggle("RTMP waiting close", isOn: Binding(get: {
                    model.database.debug!.rtmpWaitingClose!
                }, set: { value in
                    model.database.debug!.rtmpWaitingClose = value
                    model.setRtmpWaitingClose()
                    model.store()
                }))
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
