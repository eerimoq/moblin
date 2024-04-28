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

    private func onPixelFormatChange(format: String) {
        model.database.debug!.pixelFormat = format
        model.setPixelFormat()
        model.store()
        model.reloadStream()
        model.sceneUpdated()
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
                Toggle("Global tone mapping", isOn: Binding(get: {
                    model.getGlobalToneMappingOn()
                }, set: { value in
                    model.setGlobalToneMapping(on: value)
                }))
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Pixel format"),
                    onChange: onPixelFormatChange,
                    items: InlinePickerItem.fromStrings(values: pixelFormats),
                    selectedId: model.database.debug!.pixelFormat!
                )) {
                    TextItemView(
                        name: String(localized: "Pixel format"),
                        value: model.database.debug!.pixelFormat!
                    )
                }
                NavigationLink(destination: DebugBeautyFilterSettingsView(
                    brightness: model.database.debug!.beautyFilterSettings!.brightness,
                    contrast: model.database.debug!.beautyFilterSettings!.contrast,
                    saturation: model.database.debug!.beautyFilterSettings!.saturation,
                    cuteRadius: model.database.debug!.beautyFilterSettings!.cuteRadius!,
                    cuteScale: model.database.debug!.beautyFilterSettings!.cuteScale!,
                    cuteOffset: model.database.debug!.beautyFilterSettings!.cuteOffset!
                )) {
                    Text("Beauty filter")
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
