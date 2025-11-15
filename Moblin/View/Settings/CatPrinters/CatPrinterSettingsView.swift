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
    @ObservedObject var catPrinters: SettingsCatPrinters
    @ObservedObject private var scanner = catPrinterScanner
    @ObservedObject var device: SettingsCatPrinter
    @ObservedObject var status: StatusTopRight

    private func state() -> String {
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
                NameEditView(name: $device.name, existingNames: catPrinters.devices)
            }
            Section {
                NavigationLink {
                    CatPrinterScannerSettingsView(
                        onChange: onDeviceChange,
                        selectedId: device.bluetoothPeripheralId?.uuidString ?? String(localized: "Select device")
                    )
                } label: {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundStyle(.gray)
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
                Toggle(isOn: $device.printSnapshots) {
                    Text("Print snapshots")
                }
                NavigationLink {
                    Form {
                        NavigationLink {
                            TwitchAlertsSettingsView(title: String(localized: "Twitch"), alerts: device.printTwitch)
                        } label: {
                            TwitchLogoAndNameView()
                        }
                        NavigationLink {
                            KickAlertsSettingsView(title: String(localized: "Kick"),
                                                   alerts: device.printKick,
                                                   showBans: false)
                        } label: {
                            KickLogoAndNameView()
                        }
                    }
                    .navigationTitle("Print alerts")
                } label: {
                    Text("Print alerts")
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
                    TextButtonView("Test") {
                        model.catPrinterPrintTestImage(device: device)
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
