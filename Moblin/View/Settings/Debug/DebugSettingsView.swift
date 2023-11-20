import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @State var srtOverheadBandwidth: Float

    private func onLogLevelChange(level: String) {
        guard let level = SettingsLogLevel(rawValue: level) else {
            return
        }
        logger.debugEnabled = level == .debug
        model.database.debug!.logLevel = level
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView()) {
                    Text("Log")
                }
                NavigationLink(destination: InlinePickerView(title: "Log Level",
                                                             onChange: onLogLevelChange,
                                                             items: logLevels,
                                                             selected: model.database
                                                                 .debug!.logLevel
                                                                 .rawValue))
                {
                    TextItemView(
                        name: "Log level",
                        value: model.database.debug!.logLevel.rawValue
                    )
                }
                NavigationLink(destination: DebugAudioSettingsView()) {
                    Text("Audio")
                }
                Toggle("SRT overlay", isOn: Binding(get: {
                    model.database.debug!.srtOverlay
                }, set: { value in
                    model.database.debug!.srtOverlay = value
                    model.store()
                }))
                NavigationLink(
                    destination: DebugAdaptiveBitrateSettingsView(
                        packetsInFlight: Double(model
                            .getAdaptiveBitratePacketsInFlight())
                    )
                ) {
                    Text("Adaptive bitrate")
                }
                HStack {
                    Text("Exposure")
                    Slider(
                        value: $model.bias,
                        in: -2 ... 2,
                        step: 0.2,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setExposureBias(bias: model.bias)
                        }
                    )
                    .onChange(of: model.bias) { _ in
                        model.setExposureBias(bias: model.bias)
                    }
                    Text(formatOneDecimal(value: model.bias))
                        .frame(width: 40)
                }
                HStack {
                    Text("SRT oheadbw")
                    Slider(
                        value: $srtOverheadBandwidth,
                        in: 5 ... 50,
                        step: 5,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.debug!
                                .srtOverheadBandwidth = Int32(srtOverheadBandwidth)
                            model.store()
                        }
                    )
                    Text(String(Int32(srtOverheadBandwidth)))
                        .frame(width: 40)
                }
            }
        }
        .navigationTitle("Debug")
        .toolbar {
            SettingsToolbar()
        }
    }
}
