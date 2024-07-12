import SwiftUI

private let audioLevels = [String(localized: "Bar"), String(localized: "Decibel")]

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model

    private func onAudioLevelChange(type: String) {
        model.database.show.audioBar = type == String(localized: "Bar")
        model.store()
    }

    private func audioLevel() -> String {
        return model.database.show.audioBar ? String(localized: "Bar") : String(localized: "Decibel")
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: GlobalQuickButtonsSettingsView()) {
                    Text("Quick buttons")
                }
                if model.database.showAllSettings! {
                    NavigationLink(destination: StreamButtonsSettingsView(
                        background: model.database.streamButtonColor!.color()
                    )) {
                        Text("Stream button")
                    }
                    if !ProcessInfo().isiOSAppOnMac {
                        Toggle("Battery percentage", isOn: Binding(get: {
                            model.database.batteryPercentage!
                        }, set: { value in
                            model.database.batteryPercentage = value
                            model.store()
                            model.objectWillChange.send()
                        }))
                    }
                    NavigationLink(destination: LocalOverlaysSettingsView()) {
                        Text("Local overlays")
                    }
                    NavigationLink(destination: InlinePickerView(title: String(localized: "Audio level"),
                                                                 onChange: onAudioLevelChange,
                                                                 items: InlinePickerItem
                                                                     .fromStrings(values: audioLevels),
                                                                 selectedId: audioLevel()))
                    {
                        TextItemView(name: "Audio level", value: audioLevel())
                    }
                    NavigationLink(destination: LocalOverlaysNetworkInterfaceNamesSettingsView()) {
                        Text("Network interface names")
                    }
                    Toggle("Low bitrate warning", isOn: Binding(get: {
                        model.database.lowBitrateWarning!
                    }, set: { value in
                        model.database.lowBitrateWarning = value
                        model.store()
                    }))
                    Toggle("Recording confirmations", isOn: Binding(get: {
                        model.database.startStopRecordingConfirmations!
                    }, set: { value in
                        model.database.startStopRecordingConfirmations = value
                        model.store()
                    }))
                }
            }
            Section {
                Toggle("Vibrate", isOn: Binding(get: {
                    model.database.vibrate!
                }, set: { value in
                    model.database.vibrate = value
                    model.store()
                    model.setAllowHapticsAndSystemSoundsDuringRecording()
                }))
            } footer: {
                VStack(alignment: .leading) {
                    Text("Enable to vibrate the device when the following toasts appear:")
                    Text("")
                    Text("• \(fffffMessage)")
                    Text("• \(failedToConnectMessage("Main"))")
                    Text("• \(formatWarning(lowBitrateMessage))")
                    Text("• \(formatWarning(lowBatteryMessage))")
                    Text("• \(formatWarning(flameRedMessage))")
                    Text("")
                    Text("Make sure silent mode is off for vibrations to work.")
                }
            }
            if model.database.showAllSettings! {
                if !ProcessInfo().isiOSAppOnMac {
                    Section {
                        Toggle(isOn: Binding(get: {
                            model.database.portrait!
                        }, set: { value in
                            model.database.portrait = value
                            model.store()
                            model.updateOrientationLock()
                        })) {
                            Text("Portrait")
                        }
                    } footer: {
                        VStack(alignment: .leading) {
                            Text("Useful when using an external camera and a portrait phone holder.")
                            Text("")
                            Text(
                                "To stream in portrait, enable Settings → Streams → \(model.stream.name) → Portrait."
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Display")
        .toolbar {
            SettingsToolbar()
        }
    }
}
