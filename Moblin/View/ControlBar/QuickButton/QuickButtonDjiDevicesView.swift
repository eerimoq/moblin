import SwiftUI

private struct DeviceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        Toggle(isOn: Binding(get: {
            device.isStarted
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
                Text(formatDjiDeviceState(state: device.state))
                    .foregroundColor(.gray)
            }
        }
        .disabled(!device.canStartLive())
    }
}

struct QuickButtonDjiDevicesView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.djiDevices.devices) { device in
                        DeviceView(device: device)
                    }
                }
            }
            Section {
                NavigationLink {
                    DjiDevicesSettingsView(djiDevices: model.database.djiDevices)
                } label: {
                    Label("DJI devices", systemImage: "appletvremote.gen1")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("DJI devices")
    }
}
