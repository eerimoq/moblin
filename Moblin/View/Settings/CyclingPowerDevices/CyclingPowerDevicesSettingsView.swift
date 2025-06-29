import SwiftUI

private struct CyclingPowerDeviceSettingsWrapperView: View {
    let device: SettingsCyclingPowerDevice
    let status: StatusTopRight
    @State var name: String

    var body: some View {
        NavigationLink {
            CyclingPowerDeviceSettingsView(status: status, device: device, name: $name)
        } label: {
            Text(name)
        }
    }
}

struct CyclingPowerDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "CyclingPowerDevice")
                }
            }
            Section {
                List {
                    ForEach(model.database.cyclingPowerDevices.devices) { device in
                        CyclingPowerDeviceSettingsWrapperView(device: device,
                                                              status: model.statusTopRight,
                                                              name: device.name)
                    }
                    .onDelete { offsets in
                        model.database.cyclingPowerDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsCyclingPowerDevice()
                    device.name = "My device"
                    model.database.cyclingPowerDevices.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Cycling power devices")
    }
}
