import SwiftUI

private func formatGarminDeviceState(state: GarminDeviceState?) -> String {
    if state == nil || state == .disconnected {
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

struct GarminDeviceSettingsView: View {
    let model: Model
    @ObservedObject private var scanner = garminScanner
    @ObservedObject var garminDevices: SettingsGarminDevices
    @ObservedObject var device: SettingsGarminDevice
    @ObservedObject var status: StatusTopRight

    private func state() -> String {
        return formatGarminDeviceState(state: status.garminDeviceState)
    }

    private func canEnable() -> Bool {
        return device.bluetoothPeripheralId != nil
    }

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let peripheral = scanner.discoveredPeripherals.first(where: { $0.identifier == deviceId })
        else {
            return
        }
        device.bluetoothPeripheralName = peripheral.name
        device.bluetoothPeripheralId = deviceId
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $device.name, existingNames: garminDevices.devices)
                } footer: {
                    Text("Use {garminHeartRate}, {garminPace}, {garminCadence} or {garminDistance} in a text widget.")
                }
                Section {
                    NavigationLink {
                        GarminDeviceScannerSettingsView(
                            onChange: onDeviceChange,
                            selectedId: device.bluetoothPeripheralId?
                                .uuidString ?? String(localized: "Select device")
                        )
                    } label: {
                        GrayTextView(
                            text: device.bluetoothPeripheralName ?? String(localized: "Select device")
                        )
                    }
                    .disabled(model.isGarminDeviceEnabled(device: device))
                } header: {
                    Text("Device")
                }
                Section {
                    Toggle("Enabled", isOn: $device.enabled)
                        .onChange(of: device.enabled) { _ in
                            if device.enabled {
                                model.enableGarminDevice(device: device)
                            } else {
                                model.disableGarminDevice(device: device)
                            }
                        }
                        .disabled(!canEnable())
                }
                if device.enabled {
                    Section {
                        HCenter {
                            Text(state())
                        }
                    }
                }
                Section {
                    Button("Reset distance") {
                        model.resetGarminDistance(device: device)
                    }
                }
            }
            .onAppear {
                model.setCurrentGarminDevice(device: device)
            }
            .navigationTitle("Garmin device")
        } label: {
            Text(device.name)
        }
    }
}
