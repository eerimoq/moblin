import SwiftUI

struct DjiControllerSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Control and monitor DJI devices. WIP!")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "SSID"),
                    value: "Qvist",
                    onSubmit: { _ in }
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: "mypass",
                    onSubmit: { _ in }
                )
            } header: {
                Text("WiFi")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: "rtmp://1.2.3.4:1935/app/oa4",
                    onSubmit: { _ in }
                )
            } header: {
                Text("RTMP")
            }
            Section {
                Button(action: {}, label: {
                    HStack {
                        Spacer()
                        Text("Start live stream")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("DJI controller")
        .toolbar {
            SettingsToolbar()
        }
    }
}
