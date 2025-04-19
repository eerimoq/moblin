import SwiftUI

private func formatTeslaVehicleState(state: TeslaVehicleState?) -> String {
    if state == nil || state == .idle {
        return String(localized: "Disconnected")
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

private struct TeslaSettingsConfigurationView: View {
    @EnvironmentObject var model: Model

    private var tesla: SettingsTesla {
        return model.database.tesla!
    }

    private func onSubmitVin(value: String) {
        tesla.vin = value.trim()
        model.reloadTeslaVehicle()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "VIN"),
                    value: tesla.vin,
                    onSubmit: onSubmitVin
                )
            } footer: {
                Text("Scroll down in your Tesla app and copy it.")
            }
            Section {
                Button {
                    tesla.privateKey = teslaGeneratePrivateKey().pemRepresentation
                    model.reloadTeslaVehicle()
                } label: {
                    HCenter {
                        Text("Generate new key")
                    }
                }
            } footer: {
                Text("""
                Moblin identifies itself to the vehicle with this key. Tap the button below to add \
                it to your vehicle.
                """)
            }
            Section {
                Button {
                    model.teslaAddKeyToVehicle()
                } label: {
                    HCenter {
                        Text("Add key to vehicle")
                    }
                }
                .disabled(tesla.vin.isEmpty || tesla.privateKey.isEmpty || model.teslaVehicleState != .connected)
            } footer: {
                Text("Remove keys in Controls → Locks on your Tesla's center screen.")
            }
        }
        .navigationTitle("Configuration")
    }
}

struct TeslaSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    Image("Tesla")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.tesla!.enabled!
                }, set: {
                    model.database.tesla!.enabled = $0
                    model.reloadTeslaVehicle()
                })) {
                    Text("Enabled")
                }
                NavigationLink {
                    TeslaSettingsConfigurationView()
                } label: {
                    Text("Configuration")
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
                .disabled(!model.teslaVehicleInfotainmentConnected)
            }
            Section {
                Button {
                    model.teslaHonk()
                } label: {
                    HCenter {
                        Text("Honk")
                    }
                }
                .disabled(!model.teslaVehicleInfotainmentConnected)
            }
            Section {
                Button {
                    model.teslaOpenTrunk()
                } label: {
                    HCenter {
                        Text("Open trunk")
                    }
                }
                .disabled(!model.teslaVehicleVehicleSecurityConnected)
            }
            Section {
                Button {
                    model.teslaCloseTrunk()
                } label: {
                    HCenter {
                        Text("Close trunk")
                    }
                }
                .disabled(!model.teslaVehicleVehicleSecurityConnected)
            }
            Section {
                Button {
                    model.mediaNextTrack()
                } label: {
                    HCenter {
                        Text("Next media track")
                    }
                }
                .disabled(!model.teslaVehicleInfotainmentConnected)
            }
            Section {
                Button {
                    model.mediaPreviousTrack()
                } label: {
                    HCenter {
                        Text("Previous media  track")
                    }
                }
                .disabled(!model.teslaVehicleInfotainmentConnected)
            }
            Section {
                Button {
                    model.mediaTogglePlayback()
                } label: {
                    HCenter {
                        Text("Toggle media playback")
                    }
                }
                .disabled(!model.teslaVehicleInfotainmentConnected)
            }
        }
        .navigationTitle("Tesla")
    }
}
