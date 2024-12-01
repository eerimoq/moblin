import SwiftUI

private func formatTeslaVehicleState(state: TeslaVehicleState?) -> String {
    if state == nil || state == .idle {
        return String(localized: "Not started")
    } else if state == .discovering {
        return String(localized: "Discovering")
    } else if state == .connecting {
        return String(localized: "Connecting")
    } else if state == .connected {
        return String(localized: "Connected")
    } else {
        return String(localized: "Unknown")
    }
}

private struct DebugTeslaKeySettingsView: View {
    @EnvironmentObject var model: Model
    @State var privateKey: String

    var body: some View {
        Form {
            Section {
                TextField("", text: $privateKey, axis: .vertical)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: privateKey) { _ in
                        model.database.debug.tesla!.privateKey = privateKey
                        model.reloadTeslaVehicle()
                    }
            } header: {
                Text("Key")
            } footer: {
                Text("Do not share this key with anyone!")
            }
            Section {
                Button {
                    model.database.debug.tesla!.privateKey = teslaGeneratePrivateKey().pemRepresentation
                    privateKey = model.database.debug.tesla!.privateKey
                } label: {
                    HCenter {
                        Text("Generate new key")
                    }
                }
            }
            Section {
                Button {
                    model.teslaAddKeyToVehicle()
                } label: {
                    HCenter {
                        Text("Add key to vehicle")
                    }
                }
            } footer: {
                Text("Remove the key using your Tesla's center screen.")
            }
        }
        .onDisappear {
            model.teslaStopAddKeyToVehicle()
        }
        .navigationTitle("Key")
    }
}

struct DebugTeslaSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "VIN"),
                    value: model.database.debug.tesla!.vin
                ) {
                    model.database.debug.tesla!.vin = $0.trim()
                    model.reloadTeslaVehicle()
                }
            }
            Section {
                NavigationLink {
                    DebugTeslaKeySettingsView(privateKey: model.database.debug.tesla!.privateKey)
                } label: {
                    TextItemView(
                        name: "Key",
                        value: model.database.debug.tesla!.privateKey,
                        sensitive: true,
                        color: .gray
                    )
                }
            }
            Section {
                HCenter {
                    Text(formatTeslaVehicleState(state: model.teslaVehicleState))
                }
            }
            Section {
                Button {
                    model.teslaFlashLights()
                } label: {
                    HCenter {
                        Text("Flash lights")
                    }
                }
            }
            Section {
                Button {
                    model.teslaHonk()
                } label: {
                    HCenter {
                        Text("Honk")
                    }
                }
            }
            Section {
                Button {
                    model.teslaOpenTrunk()
                } label: {
                    HCenter {
                        Text("Open trunk")
                    }
                }
            }
            Section {
                Button {
                    model.teslaCloseTrunk()
                } label: {
                    HCenter {
                        Text("Close trunk")
                    }
                }
            }
            Section {
                Button {
                    model.mediaNextTrack()
                } label: {
                    HCenter {
                        Text("Next media track")
                    }
                }
            }
            Section {
                Button {
                    model.mediaPreviousTrack()
                } label: {
                    HCenter {
                        Text("Previous media  track")
                    }
                }
            }
            Section {
                Button {
                    model.mediaTogglePlayback()
                } label: {
                    HCenter {
                        Text("Toggle media playback")
                    }
                }
            }
        }
        .navigationTitle("Tesla")
    }
}
