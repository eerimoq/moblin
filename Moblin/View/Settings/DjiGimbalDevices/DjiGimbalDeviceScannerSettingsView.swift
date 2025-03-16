import SwiftUI

struct DjiGimbalDeviceScannerSettingsView: View {
    @ObservedObject private var djiScanner: DjiGimbalDeviceScanner = .shared
    @Environment(\.dismiss) var dismiss
    var onChange: (String) -> Void
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                if djiScanner.discoveredDevices.isEmpty {
                    HCenter {
                        ProgressView()
                    }
                } else {
                    List {
                        ForEach(djiScanner.discoveredDevices.map { discoveredDevice in
                            InlinePickerItem(
                                id: discoveredDevice.peripheral.identifier.uuidString,
                                text: discoveredDevice.peripheral.name ?? String(localized: "Unknown")
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
            } footer: {
                Text("Restart the gimbal to discover it.")
            }
        }
        .onAppear {
            djiScanner.startScanningForDevices()
        }
        .onDisappear {
            djiScanner.stopScanningForDevices()
        }
        .navigationTitle("Device")
    }
}
