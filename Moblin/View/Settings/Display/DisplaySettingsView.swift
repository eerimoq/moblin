import SwiftUI

private struct ExternalDisplayContentView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        HStack {
            Text("External monitor content")
            Spacer()
            Picker("", selection: $database.externalDisplayContent) {
                ForEach(SettingsExternalDisplayContent.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: database.externalDisplayContent) { _ in
                model.setExternalDisplayContent()
            }
        }
    }
}

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    QuickButtonsSettingsView()
                } label: {
                    Text("Quick buttons")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamButtonsSettingsView(background: database.streamButtonColor.color())
                    } label: {
                        Text("Stream button")
                    }
                    if !isMac() {
                        Toggle("Battery percentage", isOn: Binding(get: {
                            database.batteryPercentage
                        }, set: { value in
                            database.batteryPercentage = value
                            model.objectWillChange.send()
                        }))
                    }
                    NavigationLink {
                        LocalOverlaysSettingsView(show: database.show)
                    } label: {
                        Text("Local overlays")
                    }
                    ExternalDisplayContentView(database: database)
                    NavigationLink {
                        LocalOverlaysNetworkInterfaceNamesSettingsView()
                    } label: {
                        Text("Network interface names")
                    }
                    Toggle("Low bitrate warning", isOn: Binding(get: {
                        database.lowBitrateWarning
                    }, set: { value in
                        database.lowBitrateWarning = value
                    }))
                    Toggle("Recording confirmations", isOn: Binding(get: {
                        database.startStopRecordingConfirmations
                    }, set: { value in
                        database.startStopRecordingConfirmations = value
                    }))
                }
            }
            Section {
                Toggle("Vibrate", isOn: Binding(get: {
                    database.vibrate
                }, set: { value in
                    database.vibrate = value
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
            if model.database.showAllSettings {
                if !isMac() {
                    Section {
                        Toggle(isOn: Binding(get: {
                            database.portrait
                        }, set: { _ in
                            model.setDisplayPortrait(portrait: !database.portrait)
                        })) {
                            Text("Portrait")
                        }
                        HStack {
                            Text("Video position")
                            Slider(value: $model.portraitVideoOffsetFromTop, in: 0 ... 1) {
                                Text("")
                            }
                        }
                        .onChange(of: model.portraitVideoOffsetFromTop) {
                            database.portraitVideoOffsetFromTop = $0
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
