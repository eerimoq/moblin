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

    private func deleteDevice(at offsets: IndexSet) {
        model.removeDjiDevices(offsets: offsets)
    }

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
                                if let offsets = makeOffsets(djiDevices.devices, device.id) {
                                    deleteDevice(at: offsets)
                                }
                            }
                    }
                    .onMove { froms, to in
                        djiDevices.devices.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete(perform: deleteDevice)
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
