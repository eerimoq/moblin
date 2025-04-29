import SwiftUI

private struct CyclingPowerDeviceSettingsWrapperView: View {
    var device: SettingsCyclingPowerDevice
    @State var name: String

    var body: some View {
        NavigationLink {
            CyclingPowerDeviceSettingsView(device: device, name: $name)
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
                    Image("CyclingPowerDevice")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
                }
            }
            Section {
                List {
                    ForEach(model.database.cyclingPowerDevices!.devices) { device in
                        CyclingPowerDeviceSettingsWrapperView(device: device, name: device.name)
                    }
                    .onDelete(perform: { offsets in
                        model.database.cyclingPowerDevices!.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsCyclingPowerDevice()
                    device.name = "My device"
                    model.database.cyclingPowerDevices!.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Cycling power devices")
    }
}
