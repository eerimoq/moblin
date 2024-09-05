import SwiftUI

struct CatPrinterScannerSettingsView: View {
    private let scanner: CatPrinterScanner = .shared
    @Environment(\.dismiss) var dismiss
    var onChange: (String) -> Void
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                if scanner.discoveredDevices.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(scanner.discoveredDevices.map { discoveredDevice in
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
            }
        }
        .onAppear {
            scanner.startScanningForDevices()
        }
        .onDisappear {
            scanner.stopScanningForDevices()
        }
        .navigationTitle("Device")
        .toolbar {
            SettingsToolbar()
        }
    }
}
