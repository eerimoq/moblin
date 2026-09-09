import SwiftUI

private func formatWorkoutDeviceState(state: WorkoutDeviceState?) -> String {
    if state == nil || state == .disconnected {
        String(localized: "Disconnected")
    } else if state == .discovering {
        String(localized: "Discovering")
    } else if state == .connecting {
        String(localized: "Connecting")
    } else if state == .connected {
        String(localized: "Connected")
    } else {
        String(localized: "Unknown")
    }
}

struct WorkoutDeviceSettingsView: View {
    let model: Model
    @ObservedObject var workoutDevices: SettingsWorkoutDevices
    @ObservedObject var device: SettingsWorkoutDevice
    @ObservedObject var status: StatusTopRight
    @ObservedObject private var scanner = workoutDeviceScanner

    private func state() -> String {
        formatWorkoutDeviceState(state: status.workoutDeviceState)
    }

    private func canEnable() -> Bool {
        device.bluetoothPeripheralId != nil
    }

    private func isValidWheelCircumference(value: String) -> String? {
        guard let millimeters = Int(value) else {
            return String(localized: "Not a number")
        }
        guard millimeters >= 500 else {
            return String(localized: "Too small")
        }
        guard millimeters <= 3000 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitWheelCircumference(value: String) {
        guard let millimeters = Int(value) else {
            return
        }
        device.wheelCircumferenceMillimeters = millimeters
        model.setWorkoutDeviceWheelCircumference(device: device)
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
                    Text("Add {heartRate:\(device.name)} to a text widget to show heart rate on stream.")
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
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Wheel circumference"),
                        value: String(device.wheelCircumferenceMillimeters),
                        onChange: isValidWheelCircumference,
                        onSubmit: submitWheelCircumference,
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) mm" }
                    )
                } footer: {
                    Text("Used to calculate speed from cycling speed and cadence (CSC) sensors.")
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
