import SwiftUI

private func formatCyclingPowerDeviceState(state: CyclingPowerDeviceState?) -> String {
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

struct CyclingPowerDeviceSettingsView: View {
    let model: Model
    @ObservedObject var cyclingPowerDevices: SettingsCyclingPowerDevices
    @ObservedObject var device: SettingsCyclingPowerDevice
    @ObservedObject var status: StatusTopRight
    @ObservedObject private var scanner = cyclingPowerScanner

    private func state() -> String {
        return formatCyclingPowerDeviceState(state: status.cyclingPowerDeviceState)
    }

    private func canEnable() -> Bool {
        return device.bluetoothPeripheralId != nil
    }

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let peripheral = scanner.discoveredPeripherals.first(where: { $0.identifier == deviceId }) else {
            return
        }
        device.bluetoothPeripheralName = peripheral.name
        device.bluetoothPeripheralId = deviceId
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $device.name, existingNames: cyclingPowerDevices.devices)
                }
                Section {
                    NavigationLink { CyclingPowerDeviceScannerSettingsView(
                        onChange: onDeviceChange,
                        selectedId: device.bluetoothPeripheralId?
                            .uuidString ?? String(localized: "Select device")
                    )
                    } label: {
                        Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .disabled(model.isCyclingPowerDeviceEnabled(device: device))
                } header: {
                    Text("Device")
                }
                Section {
                    Toggle("Enabled", isOn: $device.enabled)
                        .onChange(of: device.enabled) { _ in
                            if device.enabled {
                                model.enableCyclingPowerDevice(device: device)
                            } else {
                                model.disableCyclingPowerDevice(device: device)
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
            }
            .onAppear {
                model.setCurrentCyclingPowerDevice(device: device)
            }
            .navigationTitle("Cycling power device")
        } label: {
            Text(device.name)
        }
    }
}
