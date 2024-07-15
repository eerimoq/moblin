import SwiftUI

struct DjiDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.djiDevices!.devices) { device in
                        NavigationLink(destination: DjiDeviceSettingsView(device: device)) {
                            HStack {
                                Text(device.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.djiDevices!.devices.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    let device = SettingsDjiDevice()
                    device.name = "My device"
                    model.database.djiDevices!.devices.append(device)
                    model.store()
                    model.objectWillChange.send()
                })
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("DJI devices")
        .toolbar {
            SettingsToolbar()
        }
    }
}
