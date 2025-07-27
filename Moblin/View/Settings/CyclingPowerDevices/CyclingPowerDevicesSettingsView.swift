import SwiftUI

struct CyclingPowerDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var cyclingPowerDevices: SettingsCyclingPowerDevices

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "CyclingPowerDevice")
                }
            }
            Section {
                List {
                    ForEach(cyclingPowerDevices.devices) { device in
                        CyclingPowerDeviceSettingsView(model: model,
                                                       cyclingPowerDevices: cyclingPowerDevices,
                                                       device: device,
                                                       status: model.statusTopRight)
                    }
                    .onDelete { offsets in
                        cyclingPowerDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsCyclingPowerDevice()
                    device.name = makeUniqueName(name: SettingsCyclingPowerDevice.baseName,
                                                 existingNames: cyclingPowerDevices.devices)
                    cyclingPowerDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Cycling power devices")
    }
}
