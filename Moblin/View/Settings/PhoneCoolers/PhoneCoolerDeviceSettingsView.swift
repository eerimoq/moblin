//
//  PhoneCoolerDeviceSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

struct PhoneCoolerDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = heartRateScanner
    var device: SettingsPhoneCoolerDevice
    @Binding var name: String
    
    
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
            }
        }
    }
}
