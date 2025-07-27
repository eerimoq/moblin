import SwiftUI

struct HeartRateDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var heartRateDevices: SettingsHeartRateDevices

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
                    ForEach(heartRateDevices.devices) { device in
                        HeartRateDeviceSettingsView(model: model,
                                                    heartRateDevices: heartRateDevices,
                                                    device: device,
                                                    status: model.statusTopRight)
                    }
                    .onDelete { offsets in
                        heartRateDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsHeartRateDevice()
                    device.name = makeUniqueName(name: SettingsHeartRateDevice.baseName,
                                                 existingNames: heartRateDevices.devices)
                    heartRateDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Heart rate devices")
    }
}
