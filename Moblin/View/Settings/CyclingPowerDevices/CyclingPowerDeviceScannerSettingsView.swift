import SwiftUI

struct CyclingPowerDeviceScannerSettingsView: View {
    @ObservedObject private var scanner = cyclingPowerScanner
    @Environment(\.dismiss) var dismiss
    var onChange: (String) -> Void
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                if scanner.discoveredPeripherals.isEmpty {
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
