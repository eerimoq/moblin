import SwiftUI

struct DebugTeslaSettingsView: View {
    @EnvironmentObject var model: Model
    @State var privateKey: String

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
                TextField("", text: $privateKey, axis: .vertical)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: privateKey) { _ in
                        model.database.debug.tesla!.privateKey = privateKey
                        model.reloadTeslaVehicle()
                    }
            } header: {
                Text("Private key")
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
                        Text("Media next track")
                    }
                }
            }
            Section {
                Button {
                    model.mediaTogglePlayback()
                } label: {
                    HCenter {
                        Text("Media toggle playback")
                    }
                }
            }
            Section {
                Button {
                    model.teslaGetChargeState()
                } label: {
                    HCenter {
                        Text("Get charge state")
                    }
                }
            }
            Section {
                Button {
                    model.teslaGetDriveState()
                } label: {
                    HCenter {
                        Text("Get drive state")
                    }
                }
            }
            Section {
                Button {
                    model.teslaGetMediaState()
                } label: {
                    HCenter {
                        Text("Get media state")
                    }
                }
            }
            Section {
                Button {
                    model.teslaPing()
                } label: {
                    HCenter {
                        Text("Ping")
                    }
                }
            }
        }
        .navigationTitle("Tesla")
    }
}
