import SwiftUI

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

func formatDjiDeviceState(state: DjiDeviceState?) -> String {
    if state == nil || state == .idle {
        return String(localized: "Not started")
    } else if state == .discovering {
        return String(localized: "Discovering")
    } else if state == .connecting {
        return String(localized: "Connecting")
    } else if state == .checkingIfPaired || state == .pairing {
        return String(localized: "Pairing")
    } else if state == .stoppingStream || state == .cleaningUp {
        return String(localized: "Stopping stream")
    } else if state == .preparingStream {
        return String(localized: "Preparing to stream")
    } else if state == .settingUpWifi {
        return String(localized: "Setting up WiFi")
    } else if state == .wifiSetupFailed {
        return String(localized: "WiFi setup failed")
    } else if state == .configuring {
        return String(localized: "Configuring")
    } else if state == .startingStream {
        return String(localized: "Starting stream")
    } else if state == .streaming {
        return String(localized: "Streaming")
    } else {
        return String(localized: "Unknown")
    }
}

private struct DjiDeviceSelectDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var djiScanner: DjiDeviceScanner = .shared
    var device: SettingsDjiDevice

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let djiDevice = djiScanner.discoveredDevices
            .first(where: { $0.peripheral.identifier == deviceId })
        else {
            return
        }
        device.bluetoothPeripheralName = djiDevice.peripheral.name
        device.bluetoothPeripheralId = deviceId
        device.model = djiDevice.model
    }

    var body: some View {
        Section {
            NavigationLink {
                DjiDeviceScannerSettingsView(
                    onChange: onDeviceChange,
                    selectedId: device.bluetoothPeripheralId?.uuidString ?? String(
                        localized: "Select device"
                    )
                )
            } label: {
                Text(device.bluetoothPeripheralName ?? String(localized: "Select device"))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .disabled(model.isDjiDeviceStarted(device: device))
        } header: {
            Text("Device")
        }
    }
}

private struct DjiDeviceWiFiSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    var body: some View {
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
        } footer: {
            Text("The DJI device will connect to and stream RTMP over this WiFi.")
        }
    }
}

private struct DjiDeviceRtmpSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    private func serverUrls() -> [String] {
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId!) else {
            return []
        }
        var serverUrls: [String] = []
        for status in model.ipStatuses.filter({ $0.ipType == .ipv4 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer!.port,
                streamKey: stream.streamKey
            ))
        }
        serverUrls.append(rtmpStreamUrl(
            address: personalHotspotLocalAddress,
            port: model.database.rtmpServer!.port,
            streamKey: stream.streamKey
        ))
        for status in model.ipStatuses.filter({ $0.ipType == .ipv6 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer!.port,
                streamKey: stream.streamKey
            ))
        }
        return serverUrls
    }

    var body: some View {
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
        } footer: {
            Text("""
            Select \(String(localized: "Server")) if you want the DJI camera to stream to \
            Moblin's RTMP server on this device. Select \(String(localized: "Custom")) to \
            make the DJI camera stream to any destination.
            """)
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
        }
    }
}

private struct DjiDeviceSettingsSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    var body: some View {
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
            if device.model == .osmoAction4 || device.model == .osmoAction5Pro {
                Picker("Image stabilization", selection: Binding(get: {
                    device.imageStabilization!.toString()
                }, set: { value in
                    device.imageStabilization = SettingsDjiDeviceImageStabilization
                        .fromString(value: value)
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceImageStabilizations, id: \.self) { imageStabilization in
                        Text(imageStabilization)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
            }
            if device.model == .osmoPocket3 {
                Picker("FPS", selection: Binding(get: {
                    device.fps!
                }, set: { value in
                    device.fps = value
                    model.objectWillChange.send()
                })) {
                    ForEach(djiDeviceFpss, id: \.self) { fps in
                        Text(String(fps))
                            .tag(fps)
                    }
                }
                .disabled(model.isDjiDeviceStarted(device: device))
            }
        } footer: {
            Text("High bitrates may be unstable.")
        }
    }
}

private struct DjiDeviceAutoRestartSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    var body: some View {
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
    }
}

private struct DjiDeviceStartStopButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice

    var body: some View {
        if !model.isDjiDeviceStarted(device: device) {
            Section {
                Button(action: {
                    model.startDjiDeviceLiveStream(device: device)
                }, label: {
                    HCenter {
                        Text("Start live stream")
                    }
                })
            }
            .listRowBackground(RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(.blue, lineWidth: 2)))
            .disabled(!device.canStartLive())
        } else {
            Section {
                HCenter {
                    Button(action: {
                        model.stopDjiDeviceLiveStream(device: device)
                    }, label: {
                        Text("Stop live stream")
                    })
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.blue)
        }
    }
}

struct DjiDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    var device: SettingsDjiDevice
    @Binding var name: String

    func state() -> String {
        return formatDjiDeviceState(state: model.djiDeviceStreamingState)
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Name", value: device.name, onSubmit: { value in
                    name = value
                    device.name = value
                })
            }
            DjiDeviceSelectDeviceSettingsView(device: device)
            DjiDeviceWiFiSettingsView(device: device)
            DjiDeviceRtmpSettingsView(device: device)
            DjiDeviceSettingsSettingsView(device: device)
            DjiDeviceAutoRestartSettingsView(device: device)
            Section {
                HCenter {
                    Text(state())
                }
            }
            DjiDeviceStartStopButtonSettingsView(device: device)
        }
        .onAppear {
            model.setCurrentDjiDevice(device: device)
        }
        .navigationTitle("DJI device")
    }
}
