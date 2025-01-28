import SwiftUI

struct QuickButtonDjiDevicesView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.djiDevices!.devices) { device in
                        Toggle(isOn: Binding(get: {
                            model.isDjiDeviceStarted(device: device)
                        }, set: { value in
                            if value {
                                model.startDjiDeviceLiveStream(device: device)
                            } else {
                                model.stopDjiDeviceLiveStream(device: device)
                            }
                        })) {
                            HStack {
                                Text(device.name)
                                Spacer()
                                Text(formatDjiDeviceState(state: model.getDjiDeviceState(device: device)))
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(!device.canStartLive())
                    }
                }
            }
        }
        .navigationTitle("DJI devices")
    }
}
