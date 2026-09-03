import SwiftUI

private func formatTeslaVehicleState(state: TeslaVehicleState?) -> String {
    if state == nil || state == .idle {
        String(localized: "Disconnected")
    } else if state == .connecting {
        String(localized: "Connecting")
    } else if state == .connected {
        String(localized: "Connected")
    } else {
        String(localized: "Unknown")
    }
}

private struct TeslaSettingsConfigurationView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var tesla: Tesla
    @ObservedObject var settings: SettingsTesla

    private var database: Database {
        model.database
    }

    private func onSubmitVin(value: String) {
        database.tesla.vin = value.trim()
        model.reloadTeslaVehicle()
    }

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let peripheral = TeslaVehicleScanner.shared.discoveredPeripherals
            .first(where: { $0.identifier == deviceId })
        else {
            return
        }
        settings.bluetoothPeripheralName = peripheral.name
        settings.bluetoothPeripheralId = deviceId
        model.reloadTeslaVehicle()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TeslaVehicleScannerSettingsView(onChange: onDeviceChange)
                } label: {
                    GrayTextView(text: settings
                        .bluetoothPeripheralName ?? String(localized: "Select vehicle"))
                }
                TextEditNavigationView(
                    title: String(localized: "VIN"),
                    value: database.tesla.vin,
                    onSubmit: onSubmitVin
                )
            } header: {
                Text("Vehicle")
            } footer: {
                Text("Scroll down in your Tesla app and copy it.")
            }
            Section {
                TextButtonView("Generate new key") {
                    database.tesla.privateKey = teslaGeneratePrivateKey().pemRepresentation
                    model.reloadTeslaVehicle()
                }
            } footer: {
                Text("""
                Moblin identifies itself to the vehicle with this key. Tap the button below to add \
                it to your vehicle.
                """)
            }
            Section {
                TextButtonView("Add key to vehicle") {
                    model.teslaAddKeyToVehicle()
                }
                .disabled(database.tesla.vin.isEmpty || database.tesla.privateKey.isEmpty || tesla
                    .vehicleState != .connected)
            } footer: {
                Text("Remove keys in Controls → Locks on your Tesla's center screen.")
            }
        }
        .navigationTitle("Configuration")
    }
}

struct TeslaSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var tesla: Tesla

    var body: some View {
        Form {
            Section {
                HCenter {
                    Image("Tesla")
                        .resizable()
                        .scaledToFit()
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.tesla.enabled
                }, set: {
                    model.database.tesla.enabled = $0
                    model.reloadTeslaVehicle()
                })) {
                    Text("Enabled")
                }
                NavigationLink {
                    TeslaSettingsConfigurationView(tesla: tesla, settings: model.database.tesla)
                } label: {
                    Text("Configuration")
                }
            }
            Section {
                HCenter {
                    Text(formatTeslaVehicleState(state: tesla.vehicleState))
                }
            }
            Section {
                TextButtonView("Flash lights") {
                    model.teslaFlashLights()
                }
                .disabled(!tesla.vehicleInfotainmentConnected)
            }
            Section {
                TextButtonView("Honk") {
                    model.teslaHonk()
                }
                .disabled(!tesla.vehicleInfotainmentConnected)
            }
            Section {
                TextButtonView("Open trunk") {
                    model.teslaOpenTrunk()
                }
                .disabled(!tesla.vehicleVehicleSecurityConnected)
            }
            Section {
                TextButtonView("Close trunk") {
                    model.teslaCloseTrunk()
                }
                .disabled(!tesla.vehicleVehicleSecurityConnected)
            }
            Section {
                TextButtonView("Next media track") {
                    model.mediaNextTrack()
                }
                .disabled(!tesla.vehicleInfotainmentConnected)
            }
            Section {
                TextButtonView("Previous media track") {
                    model.mediaPreviousTrack()
                }
                .disabled(!tesla.vehicleInfotainmentConnected)
            }
            Section {
                TextButtonView("Toggle media playback") {
                    model.mediaTogglePlayback()
                }
                .disabled(!tesla.vehicleInfotainmentConnected)
            }
        }
        .navigationTitle("Tesla")
    }
}
