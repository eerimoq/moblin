//
//  PhoneCoolerDevicesSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

private struct PhoneCoolerDeviceSettingsWrapperView: View {
    var device: SettingsPhoneCoolerDevice
    @State var name: String

    var body: some View {
        NavigationLink {
            PhoneCoolerDeviceSettingsView(device: device, name: $name)
        } label: {
            Text(name)
        }
    }
}

struct PhoneCoolerDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "BlackSharkMagCooler4Pro")
                }
            }
            Section {
                List {
                    ForEach(model.database.phoneCoolerDevices.devices) { device in
                        PhoneCoolerDeviceSettingsWrapperView(device: device, name: device.name)
                    }
                    .onDelete(perform: { offsets in
                        model.database.phoneCoolerDevices.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsPhoneCoolerDevice()
                    device.name = "My phone cooler"
                    model.database.phoneCoolerDevices.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Phone Coolers")
    }
}
