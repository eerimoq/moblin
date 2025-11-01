import SwiftUI

private struct ExternalDisplayContentView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Picker("External monitor content", selection: $database.externalDisplayContent) {
            ForEach(SettingsExternalDisplayContent.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: database.externalDisplayContent) { _ in
            model.setExternalDisplayContent()
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
                    QuickButtonsSettingsView(model: model)
                } label: {
                    Text("Quick buttons")
                }
                Toggle("Big buttons", isOn: $database.bigButtons)
                if database.showAllSettings {
                    NavigationLink {
                        StreamButtonsSettingsView(database: database)
                    } label: {
                        Text("Stream button")
                    }
                    NavigationLink {
                        LocalOverlaysSettingsView(show: database.show)
                    } label: {
                        Text("Local overlays")
                    }
                    ExternalDisplayContentView(database: database)
                    NavigationLink {
                        LocalOverlaysNetworkInterfaceNamesSettingsView(database: database)
                    } label: {
                        Text("Network interface names")
                    }
                    Toggle("Low bitrate warning", isOn: $database.lowBitrateWarning)
                    Toggle("Recording confirmations", isOn: $database.startStopRecordingConfirmations)
                }
            }
            Section {
                Toggle("Vibrate", isOn: $database.vibrate)
                    .onChange(of: database.vibrate) { _ in
                        model.setAllowHapticsAndSystemSoundsDuringRecording()
                    }
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
            if database.showAllSettings {
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
