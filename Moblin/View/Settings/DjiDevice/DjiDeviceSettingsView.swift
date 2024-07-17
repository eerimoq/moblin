import SwiftUI

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

struct DjiDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    let djiScanner: DjiDeviceScanner = DjiDeviceScanner.shared
    var device: SettingsDjiDevice
    @State private var isDevicePickerVisible = false

    private func serverUrls() -> [String] {
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId!) else {
            return []
        }
        var serverUrls: [String] = []
        for status in model.ipStatuses {
            serverUrls.append(rtmpStreamUrl(
                address: status.ip,
                port: model.database.rtmpServer!.port,
                streamKey: stream.streamKey
            ))
        }
        serverUrls.append(rtmpStreamUrl(
            address: personalHotspotLocalAddress,
            port: model.database.rtmpServer!.port,
            streamKey: stream.streamKey
        ))
        return serverUrls
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    device.name = value
                    model.store()
                })
            }
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Select device"),
                    onChange: { value in
                        print(device.peripheralId.debugDescription)
                        print(value);
                        device.peripheralId = UUID(uuidString: value)
                        print(device.peripheralId?.uuidString ?? "Not set")
                    },
                    footers: [
                        String(localized: """
                        Make sure your device is connected and that other apps are not currently connected to the device. \
                        Make sure your phone is relatively near the device. \
                        If you still dont see your device, turn your device off and then on again.
                        """),
                    ],
                    items: djiScanner.discoveredDevices.map {device in
                        InlinePickerItem(id: device.identifier.uuidString, text: device.name ?? "Unknown")
                    },
                    selectedId: device.peripheralId?.uuidString ?? "Select device"
                ), isActive: $isDevicePickerVisible) {
                    HStack {
                        Text(String(localized: "Target device"))
                        Spacer()
                        Text(device.peripheralId?.uuidString ?? "Select device")
                                .foregroundColor(.gray)
                                .lineLimit(1)
                    }
                }
            } header: {
                Text("Device")
            }.onChange(of: isDevicePickerVisible){ isVisible in
                if isVisible {
                    djiScanner.startScanningForDevices()
                } else {
                    djiScanner.stopScanningForDevices()
                }
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
                    },
                    sensitive: true
                )
            } header: {
                Text("WiFi")
            }
            Section {
                Picker("Type", selection: Binding(get: {
                    device.rtmpUrlType!.toString()
                }, set: { value in
                    device.rtmpUrlType = SettingsDjiDeviceUrlType.fromString(value: value)
                    model.store()
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceUrlTypes, id: \.self) {
                        Text($0)
                    }
                }
                if device.rtmpUrlType == .server {
                    Picker("Stream", selection: Binding(get: {
                        device.serverRtmpStreamId!
                    }, set: { value in
                        device.serverRtmpStreamId = value
                        device.serverRtmpUrl = serverUrls().first ?? ""
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        ForEach(model.database.rtmpServer!.streams) { stream in
                            Text(stream.name)
                                .tag(stream.id)
                        }
                    }
                    Picker("URL", selection: Binding(get: {
                        device.serverRtmpUrl!
                    }, set: { value in
                        device.serverRtmpUrl = value
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        ForEach(serverUrls(), id: \.self) { serverUrl in
                            Text(serverUrl)
                                .tag(serverUrl)
                        }
                    }
                } else if device.rtmpUrlType == .custom {
                    TextEditNavigationView(
                        title: String(localized: "URL"),
                        value: device.customRtmpUrl!,
                        onSubmit: { value in
                            device.customRtmpUrl = value
                            model.store()
                        }
                    )
                }
            } header: {
                Text("RTMP")
            }
            if device.rtmpUrlType == .server, false {
                Section {
                    Toggle(isOn: Binding(get: {
                        device.autoRestartStream!
                    }, set: { value in
                        device.autoRestartStream = value
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        Text("Auto-restart live stream when broken")
                    }
                }
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
