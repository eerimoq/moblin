import SwiftUI

private struct HeartRateDeviceSettingsWrapperView: View {
    let device: SettingsHeartRateDevice
    let status: StatusTopRight
    @State var name: String

    var body: some View {
        NavigationLink {
            HeartRateDeviceSettingsView(status: status, device: device, name: $name)
        } label: {
            Text(name)
        }
    }
}

struct HeartRateDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "HeartRateDevice")
                    Image("HeartRateDeviceCoros")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(.white)
                        .frame(height: 102)
                }
            }
            Section {
                List {
                    ForEach(model.database.heartRateDevices.devices) { device in
                        HeartRateDeviceSettingsWrapperView(device: device,
                                                           status: model.statusTopRight,
                                                           name: device.name)
                    }
                    .onDelete { offsets in
                        model.database.heartRateDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsHeartRateDevice()
                    device.name = makeUniqueName(
                        name: "My device",
                        existingNames: model.database.heartRateDevices.devices
                    )
                    model.database.heartRateDevices.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Heart rate devices")
    }
}
