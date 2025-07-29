import SwiftUI

struct HeartRateDeviceScannerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = heartRateScanner
    @Environment(\.dismiss) var dismiss
    let onChange: (String) -> Void
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                if !model.bluetoothAllowed {
                    Text(bluetoothNotAllowedMessage)
                } else if scanner.discoveredPeripherals.isEmpty {
                    HCenter {
                        ProgressView()
                    }
                } else {
                    List {
                        ForEach(scanner.discoveredPeripherals.map { peripheral in
                            InlinePickerItem(
                                id: peripheral.identifier.uuidString,
                                text: peripheral.name ?? String(localized: "Unknown")
                            )
                        }) { item in
                            Button {
                                onChange(item.id)
                                dismiss()
                            } label: {
                                Text(item.text)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            scanner.startScanningForDevices()
        }
        .onDisappear {
            scanner.stopScanningForDevices()
        }
        .navigationTitle("Device")
    }
}
