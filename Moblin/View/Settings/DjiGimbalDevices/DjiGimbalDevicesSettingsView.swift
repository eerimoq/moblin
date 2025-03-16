import SwiftUI

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
                        NavigationLink {
                            DjiGimbalDeviceSettingsView(device: device)
                        } label: {
                            HStack {
                                DraggableItemPrefixView()
                                Text(device.name)
                                Spacer()
                                Text(formatDjiGimbalDeviceState(state: model.getDjiGimbalDeviceState(device: device)))
                                    .foregroundColor(.gray)
                            }
                        }
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
