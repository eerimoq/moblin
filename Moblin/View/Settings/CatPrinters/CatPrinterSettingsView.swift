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
    @ObservedObject private var scanner = catPrinterScanner
    @ObservedObject var device: SettingsCatPrinter
    @ObservedObject var status: Status

    func state() -> String {
        return formatCatPrinterState(state: status.catPrinterState)
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
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: {
                    device.name = $0
                })
            }
            Section {
                NavigationLink {
                    CatPrinterScannerSettingsView(
                        onChange: onDeviceChange,
                        selectedId: device.bluetoothPeripheralId?.uuidString ?? String(localized: "Select device")
                    )
                } label: {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .disabled(model.isCatPrinterEnabled(device: device))
            } header: {
                Text("Device")
            }
            Section {
                Toggle(isOn: $device.enabled) {
                    Text("Enabled")
                }
                .onChange(of: device.enabled) { _ in
                    if device.enabled {
                        model.enableCatPrinter(device: device)
                    } else {
                        model.disableCatPrinter(device: device)
                    }
                }
                .disabled(!canEnable())
            }
            Section {
                Toggle(isOn: $device.printChat) {
                    Text("Print chat")
                }
            }
            Section {
                Toggle(isOn: $device.printSnapshots) {
                    Text("Print snapshots")
                }
            }
            Section {
                Toggle(isOn: $device.faxMeowSound) {
                    Text("Fax meow sound")
                }
                .onChange(of: device.faxMeowSound) { _ in
                    model.catPrinterSetFaxMeowSound(device: device)
                }
            }
            if device.enabled {
                Section {
                    HCenter {
                        Text(state())
                    }
                }
                Section {
                    Button {
                        model.catPrinterPrintTestImage(device: device)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Test")
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            model.setCurrentCatPrinter(device: device)
        }
        .navigationTitle("Cat printer")
    }
}
