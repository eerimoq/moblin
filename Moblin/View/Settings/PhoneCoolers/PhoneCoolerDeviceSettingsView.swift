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
    @State private var ledColor = Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1)
    
    
    
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
    
    private func changeColor(color: Color){
        
        
        let phoneCoolerDevice = model.phoneCoolerDevices.first(where: {$0.key == device.bluetoothPeripheralId})?.value
        
        guard phoneCoolerDevice != nil else {
            print("Could not find phone cooler")
            return
        }
        
       
        phoneCoolerDevice!.setLEDColor(
            red: Int(255 * device.ledLightsColor[0]),
            green: Int(255 * device.ledLightsColor[1]),
            blue: Int(255 * device.ledLightsColor[2]),
            brightness: Int(100 * device.ledLightsColor[3])
        )
    
    }
    
    private func toggleLight(_ state: Bool){
        device.ledLightsIsEnabled = state
        device.objectWillChange.send()
        
        let phoneCoolerDevice = model.phoneCoolerDevices.first(where: {$0.key == device.bluetoothPeripheralId})?.value
        
        guard phoneCoolerDevice != nil else {
            logger.error("PhoneCoolerDeviceSettingsView: Could not find phone cooler")
            return
        }
        
        if !state {
            phoneCoolerDevice!.turnLEdOff()
        } else {
            phoneCoolerDevice!.setLEDColor(
                red: Int(255 * device.ledLightsColor[0]),
                green: Int(255 * device.ledLightsColor[1]),
                blue: Int(255 * device.ledLightsColor[2]),
                brightness: device.ledLightsColor.count == 4 ? Int(device.ledLightsColor[3]) : 1
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
                    HStack{
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
                Toggle(isOn: Binding(get: {device.ledLightsIsEnabled}, set: {value in
                    toggleLight(value)
                }), label: {Text("Enable lights")})
                
                if device.ledLightsIsEnabled {
                    ColorPicker("LED Color", selection: device.ledLightsColorBinding)
                        .onChange(of: device.ledLightsColor) { newArray in
                            //let newColor = self.getLedLightsColor()
                            
                        
                                print("Chang23")
                            DispatchQueue.main.async {
                                changeColor(color: device.getLedLightsColor())

                            }
                            
                        }
                }
                
            } header: {
                Text("Settings")
            }
        }
    }
}
