import SwiftUI

private func formatWorkoutDeviceState(state: WorkoutDeviceState?) -> String {
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

struct WorkoutDeviceSettingsView: View {
    let model: Model
    @ObservedObject private var scanner = workoutScanner
    @ObservedObject var workoutDevices: SettingsWorkoutDevices
    @ObservedObject var device: SettingsWorkoutDevice
    @ObservedObject var status: StatusTopRight

    private func state() -> String {
        return formatWorkoutDeviceState(state: status.workoutDeviceState)
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
                    NameEditView(name: $device.name, existingNames: workoutDevices.devices)
                } footer: {
                    Text("""
                    Add {heartRate:\(device.name)} to a text widget to show heart rate on stream. \
                    Add {cyclingPower:\(device.name)} to show cycling power. \
                    Add {cyclingCadence:\(device.name)} to show cycling cadence.
                    """)
                }
                Section {
                    NavigationLink {
                        WorkoutDeviceScannerSettingsView(
                            onChange: onDeviceChange,
                            selectedId: device.bluetoothPeripheralId?
                                .uuidString ?? String(localized: "Select device")
                        )
                    } label: {
                        GrayTextView(
                            text: device.bluetoothPeripheralName ?? String(localized: "Select device")
                        )
                    }
                    .disabled(model.isWorkoutDeviceEnabled(device: device))
                } header: {
                    Text("Device")
                }
                Section {
                    Toggle("Enabled", isOn: $device.enabled)
                        .onChange(of: device.enabled) { _ in
                            if device.enabled {
                                model.enableWorkoutDevice(device: device)
                            } else {
                                model.disableWorkoutDevice(device: device)
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
                model.setCurrentWorkoutDevice(device: device)
            }
            .navigationTitle("Workout device")
        } label: {
            Text(device.name)
        }
    }
}
