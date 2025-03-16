import SwiftUI

func formatDjiGimbalDeviceState(state: DjiGimbalDeviceState?) -> String {
    switch state {
    case .disconnected:
        return String(localized: "Disconnected")
    case .discovering:
        return String(localized: "Discovering")
    case .connecting:
        return String(localized: "Connecting")
    case .connected:
        return String(localized: "Connected")
    case nil:
        return String(localized: "Disconnected")
    }
}

private struct DjiGimbalDeviceSelectDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var djiScanner: DjiGimbalDeviceScanner = .shared
    var device: SettingsDjiGimbalDevice

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let djiDevice = djiScanner.discoveredDevices
            .first(where: { $0.peripheral.identifier == deviceId })
        else {
            return
        }
        device.bluetoothPeripheralName = djiDevice.peripheral.name
        device.bluetoothPeripheralId = deviceId
        device.model = djiDevice.model
    }

    var body: some View {
        Section {
            NavigationLink {
                DjiGimbalDeviceScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?.uuidString ?? String(
                        localized: "Select device"
                    )
                )
            } label: {
                Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .disabled(model.isDjiGimbalDeviceEnabled(device: device))
        } header: {
            Text("Device")
        }
    }
}

struct DjiGimbalDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiGimbalDevice

    func state() -> String {
        return formatDjiGimbalDeviceState(state: model.djiGimbalDeviceStreamingState)
    }

    private func canEnable() -> Bool {
        if device.bluetoothPeripheralId == nil {
            return false
        }
        return true
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    device.name = value
                })
            }
            DjiGimbalDeviceSelectDeviceSettingsView(device: device)
            Section {
                Toggle(isOn: Binding(get: {
                    device.enabled
                }, set: { value in
                    device.enabled = value
                    if device.enabled {
                        model.enableDjiGimbalDevice(device: device)
                    } else {
                        model.disableDjiGimbalDevice(device: device)
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
            model.setCurrentDjiGimbalDevice(device: device)
        }
        .navigationTitle("DJI gimbal")
    }
}
