import HaishinKit
import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @State var srtOverheadBandwidth: Float
    @State var cameraSwitchRemoveBlackish: Float

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
                NavigationLink(destination: InlinePickerView(title: String(localized: "Log level"),
                                                             onChange: onLogLevelChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(values: logLevels),
                                                             selectedId: model.database
                                                                 .debug!.logLevel
                                                                 .rawValue))
                {
                    TextItemView(
                        name: String(localized: "Log level"),
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
                Toggle("Let it snow", isOn: Binding(get: {
                    model.database.debug!.letItSnow!
                }, set: { value in
                    model.database.debug!.letItSnow = value
                    model.store()
                }))
            }
            Section {
                NavigationLink(
                    destination: DebugAdaptiveBitrateSettingsView(
                        packetsInFlight: Double(model
                            .getAdaptiveBitratePacketsInFlight())
                    )
                ) {
                    Text("Adaptive bitrate")
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
                Toggle("Mic per scene", isOn: Binding(get: {
                    model.database.debug!.sceneMic!
                }, set: { value in
                    model.database.debug!.sceneMic = value
                    model.store()
                }))
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
                Toggle("Location", isOn: Binding(get: {
                    model.database.debug!.location!
                }, set: { value in
                    model.database.debug!.location = value
                    model.store()
                    model.reloadLocation()
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
