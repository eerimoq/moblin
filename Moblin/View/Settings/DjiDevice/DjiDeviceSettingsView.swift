import SwiftUI

struct DjiDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    device.name = value
                    model.store()
                })
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "SSID"),
                    value: device.wifiSsid,
                    onSubmit: { value in
                        device.wifiSsid = value
                        model.store()
                    }
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: device.wifiPassword,
                    onSubmit: { value in
                        device.wifiPassword = value
                        model.store()
                    }
                )
            } header: {
                Text("WiFi")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: device.rtmpUrl,
                    onSubmit: { value in
                        device.rtmpUrl = value
                        model.store()
                    }
                )
            } header: {
                Text("RTMP")
            }
            Section {
                Button(action: {
                    model.startDjiDeviceLiveStream(device: device)
                }, label: {
                    HStack {
                        Spacer()
                        Text("Start live stream")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("DJI device")
        .toolbar {
            SettingsToolbar()
        }
    }
}
