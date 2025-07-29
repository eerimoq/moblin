import SwiftUI

private struct DjiGimbalDeviceSettingsWrapperView: View {
    @EnvironmentObject var model: Model
    let device: SettingsDjiGimbalDevice
    @State var name: String

    var body: some View {
        NavigationLink {
            DjiGimbalDeviceSettingsView(device: device, status: model.statusTopRight, name: $name)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
                Text(formatDjiGimbalDeviceState(state: model.getDjiGimbalDeviceState(device: device)))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct DjiGimbalDevicesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "DjiOsmoMobile7p")
                }
            }
            Section {
                List {
                    ForEach(model.database.djiGimbalDevices.devices) { device in
                        DjiGimbalDeviceSettingsWrapperView(device: device, name: device.name)
                    }
                    .onMove { froms, to in
                        model.database.djiGimbalDevices.devices.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        model.removeDjiGimbalDevices(offsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsDjiGimbalDevice()
                    device.name = makeUniqueName(name: SettingsDjiGimbalDevice.baseName,
                                                 existingNames: model.database.djiGimbalDevices.devices)
                    model.database.djiGimbalDevices.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a gimbal"))
            }
        }
        .navigationTitle("DJI gimbals")
    }
}
