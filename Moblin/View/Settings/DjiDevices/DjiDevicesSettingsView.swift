import SwiftUI

private struct DjiDeviceSettingsWrapperView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var djiDevices: SettingsDjiDevices
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        NavigationLink {
            DjiDeviceSettingsView(djiDevices: djiDevices, device: device, status: model.statusTopRight)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(device.name)
                Spacer()
                GrayTextView(text: formatDjiDeviceState(state: device.state))
            }
        }
    }
}

struct DjiDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var djiDevices: SettingsDjiDevices

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "DjiOa4")
                }
            }
            Section {
                List {
                    ForEach(djiDevices.devices) { device in
                        DjiDeviceSettingsWrapperView(djiDevices: djiDevices, device: device)
                            .contextMenuDeleteButton {
                                if let index = djiDevices.devices
                                    .firstIndex(where: { $0.id == device.id })
                                {
                                    model.removeDjiDevices(offsets: IndexSet(integer: index))
                                }
                            }
                    }
                    .onMove { froms, to in
                        djiDevices.devices.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        model.removeDjiDevices(offsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsDjiDevice()
                    device.name = makeUniqueName(
                        name: SettingsDjiDevice.baseName,
                        existingNames: djiDevices.devices
                    )
                    djiDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("DJI devices")
    }
}
