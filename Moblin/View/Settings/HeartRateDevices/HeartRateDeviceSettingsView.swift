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
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = heartRateScanner
    var device: SettingsHeartRateDevice
    @Binding var name: String

    func state() -> String {
        return formatHeartRateDeviceState(state: model.heartRateDeviceState)
    }

    private func canEnable() -> Bool {
        if device.bluetoothPeripheralId == nil {
            return false
        }
        return true
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
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    name = value
                    device.name = value
                })
            } footer: {
                Text("Add {heartRate:\(device.name)} to a text widget to show heart rate on stream.")
            }
            Section {
                NavigationLink { HeartRateDeviceScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?
                        .uuidString ?? String(localized: "Select device")
                )
                } label: {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .disabled(model.isHeartRateDeviceEnabled(device: device))
            } header: {
                Text("Device")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    device.enabled
                }, set: { value in
                    device.enabled = value
                    if device.enabled {
                        model.enableHeartRateDevice(device: device)
                    } else {
                        model.disableHeartRateDevice(device: device)
                    }
                }), label: {
                    Text("Enabled")
                })
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
    }
}
