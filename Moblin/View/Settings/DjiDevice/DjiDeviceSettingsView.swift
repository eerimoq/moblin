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
            if model.djiDeviceStreamingState == nil || model.djiDeviceStreamingState == .idle {
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
                .listRowBackground(RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(.blue, lineWidth: 2)))
            } else if model.djiDeviceStreamingState == .discovering {
                Section {
                    HStack {
                        Spacer()
                        Text("Discovering...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .connecting {
                Section {
                    HStack {
                        Spacer()
                        Text("Connecting...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .checkingIfPaired || model
                .djiDeviceStreamingState == .pairing
            {
                Section {
                    HStack {
                        Spacer()
                        Text("Pairing...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .stoppingStream || model
                .djiDeviceStreamingState == .cleaningUp
            {
                Section {
                    HStack {
                        Spacer()
                        Text("Stopping stream...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .preparingStream {
                Section {
                    HStack {
                        Spacer()
                        Text("Preparing to stream...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .settingUpWifi {
                Section {
                    HStack {
                        Spacer()
                        Text("Setting up WiFi...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .startingStream {
                Section {
                    HStack {
                        Spacer()
                        Text("Starting stream...")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.gray)
            } else if model.djiDeviceStreamingState == .streaming {
                Section {
                    HStack {
                        Spacer()
                        Button(action: {
                            model.stopDjiDeviceLiveStream(device: device)
                        }, label: {
                            Text("Stop live stream")
                        })
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color.blue)
            } else {
                Section {
                    HStack {
                        Spacer()
                        Text("Unknown device state")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("DJI device")
        .toolbar {
            SettingsToolbar()
        }
    }
}
