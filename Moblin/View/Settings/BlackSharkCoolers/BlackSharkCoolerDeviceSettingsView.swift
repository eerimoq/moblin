//
//  BlackSharkCoolerDeviceSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

private func formatBlackSharkCoolerDeviceState(state: BlackSharkCoolerDeviceState?) -> String {
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

struct BlackSharkCoolerDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = blackSharkCoolerScanner
    @ObservedObject var blackSharkCoolerDevices: SettingsBlackSharkCoolerDevices
    @ObservedObject var device: SettingsBlackSharkCoolerDevice
    @ObservedObject var status: StatusTopRight

    private func state() -> String {
        return formatBlackSharkCoolerDeviceState(state: status.blackSharkCoolerDeviceState)
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

    private func changeColor() {
        let blackSharkCoolerDevice = model.blackSharkCoolerDevices
            .first(where: { $0.key == device.bluetoothPeripheralId })?.value
        guard let blackSharkCoolerDevice else {
            logger.error("Could not find phone cooler")
            return
        }
        blackSharkCoolerDevice.setLedColor(
            color: device.rgbLightColor,
            brightness: Int(device.rgbLightBrightness)
        )
    }

    private func toggleLight() {
        guard let blackSharkCoolerDevice = model.blackSharkCoolerDevices
            .first(where: { $0.key == device.bluetoothPeripheralId })?
            .value
        else {
            logger.error("Could not find phone cooler")
            return
        }
        if device.rgbLightEnabled {
            blackSharkCoolerDevice.setLedColor(color: device.rgbLightColor, brightness: Int(device.rgbLightBrightness))
        } else {
            blackSharkCoolerDevice.turnLedOff()
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $device.name, existingNames: blackSharkCoolerDevices.devices)
                }
                Section {
                    NavigationLink {
                        BlackSharkCoolerDeviceScannerSettingsView(
                            onChange: onDeviceChange,
                            selectedId: device.bluetoothPeripheralId?.uuidString ?? String(localized: "Select device")
                        )
                    } label: {
                        Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .disabled(device.enabled)
                } header: {
                    Text("Device")
                } footer: {
                    if let phoneTemp = status.blackSharkCoolerPhoneTemp,
                       let exhaustTemp = status.blackSharkCoolerExhaustTemp
                    {
                        HStack {
                            Text("Phone: \(phoneTemp) °C")
                            Spacer()
                            Text("Exhaust: \(exhaustTemp) °C")
                        }
                    }
                }
                Section {
                    Toggle("Enabled", isOn: $device.enabled)
                        .onChange(of: device.enabled) { _ in
                            if device.enabled {
                                model.enableBlackSharkDevice(device: device)
                            } else {
                                model.disableBlackSharkCoolerDevice(device: device)
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
                    Toggle("Enabled", isOn: $device.rgbLightEnabled)
                        .onChange(of: device.rgbLightEnabled) { _ in
                            toggleLight()
                        }
                    if device.rgbLightEnabled {
                        ColorPicker("Color", selection: $device.rgbLightColorColor, supportsOpacity: false)
                            .onChange(of: device.rgbLightColorColor) { _ in
                                guard let color = device.rgbLightColorColor.toStandardRgb() else {
                                    return
                                }
                                device.rgbLightColor = color
                                changeColor()
                            }
                        HStack {
                            Text("Brightness")
                            Slider(
                                value: $device.rgbLightBrightness,
                                in: 0 ... 100
                            )
                            .onChange(of: device.rgbLightBrightness) { _ in
                                changeColor()
                            }
                        }
                    }
                } header: {
                    Text("RGB light")
                }
            }
            .navigationTitle("Cooler")
        } label: {
            Text(device.name)
        }
    }
}
