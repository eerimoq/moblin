import SwiftUI

private let audioLevels = [String(localized: "Bar"), String(localized: "Decibel")]

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model

    private func onAudioLevelChange(type: String) {
        model.database.show.audioBar = type == String(localized: "Bar")
    }

    private func audioLevel() -> String {
        return model.database.show.audioBar ? String(localized: "Bar") : String(localized: "Decibel")
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    GlobalQuickButtonsSettingsView()
                } label: {
                    Text("Quick buttons")
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        StreamButtonsSettingsView(background: model.database.streamButtonColor!.color())
                    } label: {
                        Text("Stream button")
                    }
                    if !ProcessInfo().isiOSAppOnMac {
                        Toggle("Battery percentage", isOn: Binding(get: {
                            model.database.batteryPercentage
                        }, set: { value in
                            model.database.batteryPercentage = value
                            model.objectWillChange.send()
                        }))
                    }
                    NavigationLink {
                        LocalOverlaysSettingsView()
                    } label: {
                        Text("Local overlays")
                    }
                    HStack {
                        Text("Audio level")
                        Spacer()
                        Picker("", selection: Binding(get: {
                            audioLevel()
                        }, set: onAudioLevelChange)) {
                            ForEach(audioLevels, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    NavigationLink {
                        LocalOverlaysNetworkInterfaceNamesSettingsView()
                    } label: {
                        Text("Network interface names")
                    }
                    Toggle("Low bitrate warning", isOn: Binding(get: {
                        model.database.lowBitrateWarning!
                    }, set: { value in
                        model.database.lowBitrateWarning = value
                    }))
                    Toggle("Recording confirmations", isOn: Binding(get: {
                        model.database.startStopRecordingConfirmations!
                    }, set: { value in
                        model.database.startStopRecordingConfirmations = value
                    }))
                }
            }
            Section {
                Toggle("Vibrate", isOn: Binding(get: {
                    model.database.vibrate!
                }, set: { value in
                    model.database.vibrate = value
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
    }
}
