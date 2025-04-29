import SwiftUI

private struct DjiDeviceSettingsWrapperView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice
    @State var name: String

    var body: some View {
        NavigationLink {
            DjiDeviceSettingsView(device: device, name: $name)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
                Text(formatDjiDeviceState(state: model.getDjiDeviceState(device: device)))
                    .foregroundColor(.gray)
            }
        }
    }
}

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
                        DjiDeviceSettingsWrapperView(device: device, name: device.name)
                    }
                    .onMove(perform: { froms, to in
                        model.database.djiDevices!.devices.move(fromOffsets: froms, toOffset: to)
                        model.objectWillChange.send()
                    })
                    .onDelete(perform: { offsets in
                        model.removeDjiDevices(offsets: offsets)
                        model.objectWillChange.send()
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
