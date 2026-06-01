import SwiftUI

private struct DeviceView: View {
    let model: Model
    @ObservedObject var status: StatusOther
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
                GrayTextView(text: formatDjiDeviceState(state: device.state))
            }
        }
        .disabled(!device.canStartLive(status.isConnectedToIpv4WiFi()))
    }
}

struct QuickButtonDjiDevicesView: View {
    let model: Model
    @ObservedObject var djiDevices: SettingsDjiDevices

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(djiDevices.devices) {
                        DeviceView(model: model, status: model.statusOther, device: $0)
                    }
                }
            }
            ShortcutSectionView {
                NavigationLink {
                    DjiDevicesSettingsView(djiDevices: djiDevices)
                } label: {
                    Label("DJI devices", systemImage: "appletvremote.gen1")
                }
            }
        }
        .navigationTitle("DJI devices")
    }
}
