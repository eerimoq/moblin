import SwiftUI

private struct DjiGimbalDeviceSettingsWrapperView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiGimbalDevice
    @State var name: String

    var body: some View {
        NavigationLink {
            DjiGimbalDeviceSettingsView(device: device, name: $name)
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
                    Image("DjiOsmoMobile7p")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
                }
            }
            Section {
                List {
                    ForEach(model.database.djiGimbalDevices!.devices) { device in
                        DjiGimbalDeviceSettingsWrapperView(device: device, name: device.name)
                    }
                    .onMove(perform: { froms, to in
                        model.database.djiGimbalDevices!.devices.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        model.removeDjiGimbalDevices(offsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsDjiGimbalDevice()
                    device.name = "My gimbal"
                    model.database.djiGimbalDevices!.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a gimbal"))
            }
        }
        .navigationTitle("DJI gimbals")
    }
}
