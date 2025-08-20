//
//  BlackSharkCoolerDevicesSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

struct BlackSharkCoolerDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var blackSharkCoolerDevices: SettingsBlackSharkCoolerDevices

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "BlackSharkMagCooler4Pro")
                }
            }
            Section {
                List {
                    ForEach(blackSharkCoolerDevices.devices) { device in
                        BlackSharkCoolerDeviceSettingsView(blackSharkCoolerDevices: blackSharkCoolerDevices,
                                                           device: device,
                                                           status: model.statusTopRight)
                    }
                    .onDelete { offsets in
                        blackSharkCoolerDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsBlackSharkCoolerDevice()
                    device.name = makeUniqueName(name: SettingsBlackSharkCoolerDevice.baseName,
                                                 existingNames: blackSharkCoolerDevices.devices)
                    blackSharkCoolerDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a cooler"))
            }
        }
        .navigationTitle("Black Shark coolers")
    }
}
