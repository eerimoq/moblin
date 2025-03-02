import SwiftUI

struct DjiDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    Image("DjiOa4")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
                }
            }
            Section {
                List {
                    ForEach(model.database.djiDevices!.devices) { device in
                        NavigationLink {
                            DjiDeviceSettingsView(device: device)
                        } label: {
                            HStack {
                                DraggableItemPrefixView()
                                Text(device.name)
                                Spacer()
                                Text(formatDjiDeviceState(state: model.getDjiDeviceState(device: device)))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        model.database.djiDevices!.devices.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        model.removeDjiDevices(offsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsDjiDevice()
                    device.name = "My device"
                    model.database.djiDevices!.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("DJI devices")
    }
}
