import SwiftUI

private func formatCatPrinterState(state: CatPrinterState?) -> String {
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

struct CatPrinterSettingsView: View {
    @EnvironmentObject var model: Model
    private let scanner: CatPrinterScanner = .shared
    var device: SettingsCatPrinter

    func state() -> String {
        return formatCatPrinterState(state: model.catPrinterState)
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
        guard let catPrinterDevice = scanner.discoveredDevices
            .first(where: { $0.peripheral.identifier == deviceId })
        else {
            return
        }
        device.bluetoothPeripheralName = catPrinterDevice.peripheral.name
        device.bluetoothPeripheralId = deviceId
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    device.name = value
                })
            }
            Section {
                NavigationLink(destination: CatPrinterScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?
                        .uuidString ?? String(localized: "Select device")
                )) {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .disabled(model.isCatPrinterEnabled(device: device))
            } header: {
                Text("Device")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    device.enabled
                }, set: { value in
                    device.enabled = value
                    if device.enabled {
                        model.enableCatPrinter(device: device)
                    } else {
                        model.disableCatPrinter(device: device)
                    }
                }), label: {
                    Text("Enabled")
                })
                .disabled(!canEnable())
            }
            Section {
                Toggle(isOn: Binding(get: {
                    device.printChat!
                }, set: { value in
                    device.printChat = value
                }), label: {
                    Text("Print chat")
                })
            }
            if device.enabled {
                Section {
                    HStack {
                        Spacer()
                        Text(state())
                        Spacer()
                    }
                }
                Section {
                    Button(action: {
                        model.catPrinterPrintTestImage(device: device)
                    }, label: {
                        HStack {
                            Spacer()
                            Text("Test")
                            Spacer()
                        }
                    })
                }
            }
        }
        .onAppear {
            model.setCurrentCatPrinter(device: device)
        }
        .navigationTitle("Cat printer")
    }
}
