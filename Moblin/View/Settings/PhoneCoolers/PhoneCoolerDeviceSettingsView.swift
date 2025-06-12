//
//  PhoneCoolerDeviceSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

private func formatPhoneCoolerDeviceState(state: PhoneCoolerDeviceState?) -> String {
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

struct PhoneCoolerDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = phoneCoolerScanner
    @ObservedObject var device: SettingsPhoneCoolerDevice
    @Binding var name: String

    func state() -> String {
        return formatPhoneCoolerDeviceState(state: model.phoneCoolerDeviceState)
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

    private func changeColor(color _: [Double]) {
        let phoneCoolerDevice = model.phoneCoolerDevices.first(where: { $0.key == device.bluetoothPeripheralId })?.value

        guard phoneCoolerDevice != nil else {
            logger.error("Could not find phone cooler")
            return
        }

        phoneCoolerDevice!.setLEDColor(
            red: Int(device.ledLightsColor[0]),
            green: Int(device.ledLightsColor[1]),
            blue: Int(device.ledLightsColor[2]),
            brightness: Int(device.ledLightsColor[3])
        )
    }

    private func toggleLight(_ state: Bool) {
        device.ledLightsIsEnabled = state
        device.objectWillChange.send()

        let phoneCoolerDevice = model.phoneCoolerDevices.first(where: { $0.key == device.bluetoothPeripheralId })?.value

        guard phoneCoolerDevice != nil else {
            logger.error("PhoneCoolerDeviceSettingsView: Could not find phone cooler")
            return
        }

        if !state {
            phoneCoolerDevice!.turnLEdOff()
        } else {
            phoneCoolerDevice!.setLEDColor(
                red: Int(device.ledLightsColor[0]),
                green: Int(device.ledLightsColor[1]),
                blue: Int(device.ledLightsColor[2]),
                brightness: Int(device.ledLightsColor[3])
            )
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    name = value
                    device.name = value
                })
            }

            Section {
                NavigationLink { PhoneCoolerDeviceScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?
                        .uuidString ?? String(localized: "Select device")
                )
                } label: {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .disabled(device.enabled)
            } header: {
                Text("Device")
            } footer: {
                if model.phoneCoolerPhoneTemp != nil && model.phoneCoolerExhaustTemp != nil {
                    HStack {
                        Text("Phone: \(String(model.phoneCoolerPhoneTemp!)) C°")
                        Spacer()
                        Text("Exhaust: \(String(model.phoneCoolerExhaustTemp!)) C°")
                    }
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    device.enabled
                }, set: { value in
                    device.enabled = value
                    if device.enabled {
                        model.enablePhoneCoolerDevice(device: device)
                    } else {
                        model.disablePhoneCoolerDevice(device: device)
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
            Section {
                Toggle(isOn: Binding(get: { device.ledLightsIsEnabled }, set: { value in
                    toggleLight(value)
                }), label: { Text("Enable lights") })

                if device.ledLightsIsEnabled {
                    HStack {
                        Text("Red")
                        Slider(
                            value: device.ledLightsColorBinding[0],
                            in: 0 ... 100,
                            onEditingChanged: { _ in
                                changeColor(color: device.getLedLightsColor())
                            }
                        )
                    }

                    HStack {
                        Text("Green")
                        Slider(
                            value: device.ledLightsColorBinding[1],
                            in: 0 ... 100,
                            onEditingChanged: { _ in
                                changeColor(color: device.getLedLightsColor())
                            }
                        )
                    }

                    HStack {
                        Text("Blue")
                        Slider(
                            value: device.ledLightsColorBinding[2],
                            in: 0 ... 100,
                            onEditingChanged: { _ in
                                changeColor(color: device.getLedLightsColor())
                            }
                        )
                    }
                    HStack {
                        Text("Opacity")
                        Slider(
                            value: device.ledLightsColorBinding[3],
                            in: 0 ... 100,
                            onEditingChanged: { _ in
                                changeColor(color: device.getLedLightsColor())
                            }
                        )
                    }
                }

            } header: {
                Text("LED Light")
            }
            .onChange(of: device.ledLightsColor) { _ in
                DispatchQueue.main.async {
                    changeColor(color: device.getLedLightsColor())
                }
            }
        }
    }
}
