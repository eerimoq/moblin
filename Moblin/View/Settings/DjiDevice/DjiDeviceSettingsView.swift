import SwiftUI

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

struct DjiDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    private let djiScanner: DjiDeviceScanner = .shared
    var device: SettingsDjiDevice

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

    func state() -> String {
        if model.djiDeviceStreamingState == nil || model.djiDeviceStreamingState == .idle {
            return String(localized: "Not started")
        } else if model.djiDeviceStreamingState == .discovering {
            return String(localized: "Discovering...")
        } else if model.djiDeviceStreamingState == .connecting {
            return String(localized: "Connecting...")
        } else if model.djiDeviceStreamingState == .checkingIfPaired || model
            .djiDeviceStreamingState == .pairing
        {
            return String(localized: "Pairing...")
        } else if model.djiDeviceStreamingState == .stoppingStream || model
            .djiDeviceStreamingState == .cleaningUp
        {
            return String(localized: "Stopping stream...")
        } else if model.djiDeviceStreamingState == .preparingStream {
            return String(localized: "Preparing to stream...")
        } else if model.djiDeviceStreamingState == .settingUpWifi {
            return String(localized: "Setting up WiFi...")
        } else if model.djiDeviceStreamingState == .configuring {
            return String(localized: "Configuring...")
        } else if model.djiDeviceStreamingState == .startingStream {
            return String(localized: "Starting stream...")
        } else if model.djiDeviceStreamingState == .streaming {
            return String(localized: "Streaming")
        } else {
            return String(localized: "Unknown")
        }
    }

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let djiDevice = djiScanner.discoveredDevices.first(where: { $0.identifier == deviceId }) else {
            return
        }
        device.bluetoothPeripheralName = djiDevice.name
        device.bluetoothPeripheralId = deviceId
    }

    private func canStartLive() -> Bool {
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
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    device.name = value
                })
            }
            Section {
                NavigationLink(destination: DjiDeviceScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?.uuidString ?? String(localized: "Select device")
                )) {
                    Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .disabled(model.isDjiDeviceStarted(device: device))
            } header: {
                Text("Device")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "SSID"),
                    value: device.wifiSsid,
                    onSubmit: { value in
                        device.wifiSsid = value
                    }
                )
                .disabled(model.isDjiDeviceStarted(device: device))
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: device.wifiPassword,
                    onSubmit: { value in
                        device.wifiPassword = value
                    },
                    sensitive: true
                )
                .disabled(model.isDjiDeviceStarted(device: device))
            } header: {
                Text("WiFi")
            }
            Section {
                Picker("Type", selection: Binding(get: {
                    device.rtmpUrlType!.toString()
                }, set: { value in
                    device.rtmpUrlType = SettingsDjiDeviceUrlType.fromString(value: value)
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceUrlTypes, id: \.self) {
                        Text($0)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
                if device.rtmpUrlType == .server {
                    if model.database.rtmpServer!.streams.isEmpty {
                        Text("No RTMP server streams exists")
                    } else {
                        Picker("Stream", selection: Binding(get: {
                            device.serverRtmpStreamId!
                        }, set: { value in
                            device.serverRtmpStreamId = value
                            device.serverRtmpUrl = serverUrls().first ?? ""
                            model.objectWillChange.send()
                        })) {
                            ForEach(model.database.rtmpServer!.streams) { stream in
                                Text(stream.name)
                                    .tag(stream.id)
                            }
                        }
                        .disabled(model.isDjiDeviceStarted(device: device))
                        Picker("URL", selection: Binding(get: {
                            device.serverRtmpUrl!
                        }, set: { value in
                            device.serverRtmpUrl = value
                            model.objectWillChange.send()
                        })) {
                            ForEach(serverUrls(), id: \.self) { serverUrl in
                                Text(serverUrl)
                                    .tag(serverUrl)
                            }
                        }
                        .disabled(model.isDjiDeviceStarted(device: device))
                        if !model.database.rtmpServer!.enabled {
                            Text("⚠️ The RTMP server is not enabled")
                        }
                    }
                } else if device.rtmpUrlType == .custom {
                    TextEditNavigationView(
                        title: String(localized: "URL"),
                        value: device.customRtmpUrl!,
                        onSubmit: { value in
                            device.customRtmpUrl = value
                        }
                    )
                    .disabled(model.isDjiDeviceStarted(device: device))
                }
            } header: {
                Text("RTMP")
            }
            Section {
                Picker("Resolution", selection: Binding(get: {
                    device.resolution!.rawValue
                }, set: { value in
                    device.resolution = SettingsDjiDeviceResolution(rawValue: value) ?? .r1080p
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceResolutions, id: \.self) { resolution in
                        Text(resolution)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
                Picker("Bitrate", selection: Binding(get: {
                    device.bitrate!
                }, set: { value in
                    device.bitrate = value
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceBitrates, id: \.self) { bitrate in
                        Text(formatBytesPerSecond(speed: Int64(bitrate)))
                            .tag(bitrate)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
                Picker("Image stabilization", selection: Binding(get: {
                    device.imageStabilization!.toString()
                }, set: { value in
                    device.imageStabilization = SettingsDjiDeviceImageStabilization.fromString(value: value)
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceImageStabilizations, id: \.self) { imageStabilization in
                        Text(imageStabilization)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
            }
            if device.rtmpUrlType == .server {
                Section {
                    Toggle(isOn: Binding(get: {
                        device.autoRestartStream!
                    }, set: { value in
                        device.autoRestartStream = value
                        model.objectWillChange.send()
                    })) {
                        Text("Auto-restart live stream when broken")
                    }
                }
            }
            Section {
                HStack {
                    Spacer()
                    Text(state())
                    Spacer()
                }
            }
            if !model.isDjiDeviceStarted(device: device) {
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
                .disabled(!canStartLive())
            } else {
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
            }
        }
        .onAppear {
            let streams = model.database.rtmpServer!.streams
            if !streams.isEmpty {
                if !streams.contains(where: { $0.id == device.serverRtmpStreamId! }) {
                    device.serverRtmpStreamId = streams.first!.id
                }
                if !serverUrls().contains(where: { $0 == device.serverRtmpUrl! }) {
                    device.serverRtmpUrl = serverUrls().first ?? ""
                }
            }
            model.setCurrentDjiDevice(device: device)
        }
        .navigationTitle("DJI device")
        .toolbar {
            SettingsToolbar()
        }
    }
}
