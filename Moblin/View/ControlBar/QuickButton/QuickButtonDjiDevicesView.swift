import SwiftUI

struct QuickButtonDjiDevicesView: View {
    @EnvironmentObject var model: Model

    private func canStartLive(device: SettingsDjiDevice) -> Bool {
        if device.bluetoothPeripheralId == nil {
            return false
        }
        if device.wifiSsid.isEmpty {
            return false
        }
        switch device.rtmpUrlType! {
        case .server:
            if device.serverRtmpUrl!.isEmpty {
                return false
            }
        case .custom:
            if device.customRtmpUrl!.isEmpty {
                return false
            }
        }
        return true
    }

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
                            Text(device.name)
                        }
                        .disabled(!canStartLive(device: device))
                    }
                }
            }
        }
        .navigationTitle("DJI devices")
    }
}
