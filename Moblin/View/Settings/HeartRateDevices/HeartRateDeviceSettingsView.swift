import SwiftUI

private func formatHeartRateDeviceState(state: HeartRateDeviceState?) -> String {
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

struct HeartRateDeviceSettingsView: View {
    let model: Model
    @ObservedObject private var scanner = heartRateScanner
    @ObservedObject var heartRateDevices: SettingsHeartRateDevices
    @ObservedObject var device: SettingsHeartRateDevice
    @ObservedObject var status: StatusTopRight

    private func state() -> String {
        return formatHeartRateDeviceState(state: status.heartRateDeviceState)
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
                    NameEditView(name: $device.name, existingNames: heartRateDevices.devices)
                } footer: {
                    Text("Add {heartRate:\(device.name)} to a text widget to show heart rate on stream.")
                }
                Section {
                    NavigationLink {
                        HeartRateDeviceScannerSettingsView(
                            onChange: onDeviceChange,
                            selectedId: device.bluetoothPeripheralId?
                                .uuidString ?? String(localized: "Select device")
                        )
                    } label: {
                        Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .disabled(model.isHeartRateDeviceEnabled(device: device))
                } header: {
                    Text("Device")
                }
                Section {
                    Toggle("Enabled", isOn: $device.enabled)
                        .onChange(of: device.enabled) { _ in
                            if device.enabled {
                                model.enableHeartRateDevice(device: device)
                            } else {
                                model.disableHeartRateDevice(device: device)
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
                model.setCurrentHeartRateDevice(device: device)
            }
            .navigationTitle("Heart rate device")
        } label: {
            Text(device.name)
        }
    }
}
