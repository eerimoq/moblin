//
//  PhoneCoolerDevicesSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

struct PhoneCoolerDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var phoneCoolerDevices: SettingsPhoneCoolerDevices

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "BlackSharkMagCooler4Pro")
                }
            }
            Section {
                List {
                    ForEach(phoneCoolerDevices.devices) { device in
                        PhoneCoolerDeviceSettingsView(device: device)
                    }
                    .onDelete(perform: { offsets in
                        phoneCoolerDevices.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsPhoneCoolerDevice()
                    device.name = "My cooler"
                    phoneCoolerDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a cooler"))
            }
        }
        .navigationTitle("Black Shark coolers")
    }
}
