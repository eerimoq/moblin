import NetworkExtension
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
    @ObservedObject var device: SettingsDjiDevice

    private func onDeviceChange(value: String) {
        guard let deviceId = UUID(uuidString: value) else {
            return
        }
        guard let djiDevice = djiScanner.discoveredDevices.first(where: { $0.peripheral.identifier == deviceId }) else {
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
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            .disabled(device.isStarted)
        } header: {
            Text("Device")
        }
    }
}

private struct DjiDeviceWiFiSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        Section {
            NavigationLink {
                TextEditView(
                    title: String(localized: "SSID"),
                    value: device.wifiSsid,
                    onSubmit: {
                        device.wifiSsid = $0
                    }
                )
            } label: {
                TextItemView(name: String(localized: "SSID"), value: device.wifiSsid)
            }
            .disabled(device.isStarted)
            NavigationLink {
                TextEditView(
                    title: String(localized: "Password"),
                    value: device.wifiPassword,
                    onSubmit: {
                        device.wifiPassword = $0
                    }
                )
            } label: {
                TextItemView(
                    name: String(localized: "Password"),
                    value: device.wifiPassword,
                    sensitive: true
                )
            }
            .disabled(device.isStarted)
        } header: {
            Text("WiFi")
        } footer: {
            Text("The DJI device will connect to and stream RTMP over this WiFi.")
        }
        .onAppear {
            NEHotspotNetwork.fetchCurrent(completionHandler: { network in
                if device.wifiSsid.isEmpty, let network {
                    device.wifiSsid = network.ssid
                }
            })
        }
    }
}

private struct DjiDeviceRtmpSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice
    @ObservedObject var status: StatusOther
    @ObservedObject var rtmpServer: SettingsRtmpServer

    private func serverUrls() -> [String] {
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId) else {
            return []
        }
        var serverUrls: [String] = []
        for status in status.ipStatuses.filter({ $0.ipType == .ipv4 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: rtmpServer.port,
                streamKey: stream.streamKey
            ))
        }
        serverUrls.append(rtmpStreamUrl(
            address: personalHotspotLocalAddress,
            port: rtmpServer.port,
            streamKey: stream.streamKey
        ))
        for status in status.ipStatuses.filter({ $0.ipType == .ipv6 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: rtmpServer.port,
                streamKey: stream.streamKey
            ))
        }
        return serverUrls
    }

    var body: some View {
        Section {
            Picker("Type", selection: $device.rtmpUrlType) {
                ForEach(SettingsDjiDeviceUrlType.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .disabled(device.isStarted)
            if device.rtmpUrlType == .server {
                if rtmpServer.streams.isEmpty {
                    Text("No RTMP server streams exists")
                } else {
                    Picker("Stream", selection: $device.serverRtmpStreamId) {
                        ForEach(rtmpServer.streams) { stream in
                            Text(stream.name)
                                .tag(stream.id)
                        }
                    }
                    .onChange(of: device.serverRtmpStreamId) { _ in
                        device.serverRtmpUrl = serverUrls().first ?? ""
                    }
                    .disabled(device.isStarted)
                    Picker("URL", selection: $device.serverRtmpUrl) {
                        ForEach(serverUrls(), id: \.self) { serverUrl in
                            Text(serverUrl)
                                .tag(serverUrl)
                        }
                    }
                    .disabled(device.isStarted)
                    if !rtmpServer.enabled {
                        Text("⚠️ The RTMP server is not enabled")
                    }
                }
            } else if device.rtmpUrlType == .custom {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: device.customRtmpUrl,
                    onSubmit: {
                        device.customRtmpUrl = $0
                    }
                )
                .disabled(device.isStarted)
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
            let streams = rtmpServer.streams
            if !streams.isEmpty {
                if !streams.contains(where: { $0.id == device.serverRtmpStreamId }) {
                    device.serverRtmpStreamId = streams.first!.id
                }
                if !serverUrls().contains(where: { $0 == device.serverRtmpUrl }) {
                    device.serverRtmpUrl = serverUrls().first ?? ""
                }
            }
        }
        Section {
            RtmpServerSettingsView(rtmpServer: rtmpServer)
        } header: {
            Text("Shortcut")
        }
    }
}

private struct DjiDeviceSettingsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        Section {
            Picker("Resolution", selection: $device.resolution) {
                ForEach(SettingsDjiDeviceResolution.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .disabled(device.isStarted)
            Picker("Bitrate", selection: $device.bitrate) {
                ForEach(djiDeviceBitrates, id: \.self) {
                    Text(formatBytesPerSecond(speed: Int64($0)))
                }
            }
            .disabled(device.isStarted)
            if device.model == .osmoAction4 || device.model == .osmoAction5Pro || device.model == .osmoAction6 {
                Picker("Image stabilization", selection: $device.imageStabilization) {
                    ForEach(SettingsDjiDeviceImageStabilization.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .disabled(device.isStarted)
            }
            if device.model == .osmoPocket3 {
                Picker("FPS", selection: $device.fps) {
                    ForEach(djiDeviceFpss, id: \.self) {
                        Text(String($0))
                    }
                }
                .disabled(device.isStarted)
            }
        } header: {
            Text("Settings")
        } footer: {
            Text("High bitrates may be unstable.")
        }
    }
}

private struct DjiDeviceAutoRestartSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        if device.rtmpUrlType == .server {
            Section {
                Toggle(isOn: $device.autoRestartStream) {
                    Text("Auto-restart live stream when broken")
                }
            }
        }
    }
}

private struct DjiDeviceStartStopButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        if !device.isStarted {
            Section {
                TextButtonView("Start live stream") {
                    model.startDjiDeviceLiveStream(device: device)
                }
            }
            .disabled(!device.canStartLive())
        } else {
            Section {
                TextButtonView("Stop live stream") {
                    model.stopDjiDeviceLiveStream(device: device)
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.blue)
        }
    }
}

struct DjiDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var djiDevices: SettingsDjiDevices
    @ObservedObject var device: SettingsDjiDevice
    @ObservedObject var status: StatusTopRight

    func state() -> String {
        return formatDjiDeviceState(state: status.djiDeviceStreamingState)
    }

    var body: some View {
        Form {
            Section {
                NameEditView(name: $device.name, existingNames: djiDevices.devices)
            }
            DjiDeviceSelectDeviceSettingsView(device: device)
            DjiDeviceWiFiSettingsView(device: device)
            DjiDeviceRtmpSettingsView(device: device, status: model.statusOther, rtmpServer: model.database.rtmpServer)
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
