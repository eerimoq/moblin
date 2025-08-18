//
//  BlackSharkCoolerDeviceScannerSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

struct BlackSharkCoolerDeviceScannerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner = blackSharkCoolerScanner
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
                        ForEach(scanner.discoveredPeripherals
                            .filter { $0.name?.localizedCaseInsensitiveContains("black shark") == true }
                            .map { peripheral in
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
