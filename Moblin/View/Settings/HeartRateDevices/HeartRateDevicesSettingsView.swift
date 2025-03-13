import SwiftUI

struct HeartRateDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    Image("HeartRateDevice")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
                    Image("HeartRateDeviceCoros")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(.white)
                        .frame(height: 102)
                }
            }
            Section {
                List {
                    ForEach(model.database.heartRateDevices!.devices) { device in
                        NavigationLink {
                            HeartRateDeviceSettingsView(device: device)
                        } label: {
                            Text(device.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.heartRateDevices!.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsHeartRateDevice()
                    device.name = "My device"
                    model.database.heartRateDevices!.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Heart rate devices")
    }
}
