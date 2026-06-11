import NetworkExtension
import SwiftUI

func rtmpServerStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

func formatDjiDeviceState(state: DjiDeviceState?) -> String {
    if state == nil || state == .idle {
        String(localized: "Not started")
    } else if state == .discovering {
        String(localized: "Discovering")
    } else if state == .connecting {
        String(localized: "Connecting")
    } else if state == .checkingIfPaired || state == .pairing {
        String(localized: "Pairing")
    } else if state == .stoppingStream || state == .cleaningUp {
        String(localized: "Stopping stream")
    } else if state == .preparingStream {
        String(localized: "Preparing to stream")
    } else if state == .settingUpWifi {
        String(localized: "Setting up WiFi")
    } else if state == .wifiSetupFailed {
        String(localized: "WiFi setup failed")
    } else if state == .configuring {
        String(localized: "Configuring")
    } else if state == .startingStream {
        String(localized: "Starting stream")
    } else if state == .streaming {
        String(localized: "Streaming")
    } else {
        String(localized: "Unknown")
    }
}

private struct DjiDeviceSelectDeviceSettingsView: View {
    @ObservedObject private var djiScanner: DjiDeviceScanner = .shared
    @ObservedObject var device: SettingsDjiDevice

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
                GrayTextView(text: device.bluetoothPeripheralName ?? String(localized: "Select device"))
            }
            .disabled(device.isStarted)
        } header: {
            Text("Device")
        }
    }
}

private struct DjiDeviceWiFiSettingsView: View {
    let model: Model
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        Section {
            NavigationLink {
                DjiDeviceWiFiSettingsInnerView(model: model, database: model.database, device: device)
            } label: {
                TextItemLocalizedView(name: "Network", value: device.wifiSsid)
            }
            if device.wifiSsid.isEmpty {
                Text("⚠️ Enter the SSID of the network the DJI device should connect to.")
            }
        } header: {
            Text("WiFi")
        } footer: {
            Text("The DJI device will connect to and stream RTMP over this WiFi.")
        }
    }
}

private struct DjiDeviceWiFiSettingsInnerView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TextEditView(
                        title: String(localized: "SSID"),
                        value: device.wifiSsid,
                        onSubmit: {
                            device.wifiSsid = $0
                            if let password = database.savedWifiNetworks.first(where: {
                                $0.ssid == device.wifiSsid
                            })?.password {
                                device.wifiPassword = password
                            } else if !device.wifiPassword.isEmpty {
                                let network = SettingsWiFi()
                                network.ssid = device.wifiSsid
                                network.password = device.wifiPassword
                                database.savedWifiNetworks.append(network)
                            }
                        }
                    )
                } label: {
                    TextItemLocalizedView(name: "SSID", value: device.wifiSsid)
                }
                .disabled(device.isStarted)
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Password"),
                        value: device.wifiPassword,
                        onSubmit: {
                            device.wifiPassword = $0
                            if let network = database.savedWifiNetworks.first(where: {$0.ssid == device.wifiSsid}) {
                                network.password = device.wifiPassword
                            } else if !device.wifiSsid.isEmpty {
                                let network = SettingsWiFi()
                                network.ssid = device.wifiSsid
                                network.password = device.wifiPassword
                                database.savedWifiNetworks.append(network)
                            }
                        }
                    )
                } label: {
                    TextItemLocalizedView(name: "Password", value: device.wifiPassword, sensitive: true)
                }
                .disabled(device.isStarted)
            } header: {
                Text("Network")
            }
            .onAppear {
                NEHotspotNetwork.fetchCurrent(completionHandler: { network in
                    guard let ssid = network?.ssid else {
                        return
                    }
                    DispatchQueue.main.async {
                        if device.wifiSsid.isEmpty {
                            device.wifiSsid = ssid
                            device.wifiPassword = database.savedWifiNetworks
                                .first(where: { $0.ssid == ssid })?.password ?? ""
                        }
                    }
                })
                if !device.wifiSsid.isEmpty, device.wifiPassword.isEmpty {
                    device.wifiPassword = database.savedWifiNetworks
                        .first(where: { $0.ssid == device.wifiSsid })?.password ?? ""
                }
            }
            if !database.savedWifiNetworks.isEmpty {
                Section {
                    ForEach(database.savedWifiNetworks) { network in
                        Button {
                            device.wifiSsid = network.ssid
                            device.wifiPassword = network.password
                        } label: {
                            HStack {
                                Text(network.ssid)
                                    .foregroundColor(.primary)
                                Spacer()
                                if device.wifiSsid == network.ssid, device.wifiPassword == network.password {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .contextMenu {
                            if isMac() {
                                ContextMenuDeleteButtonView {
                                    database.savedWifiNetworks.removeAll(where: { $0.ssid == network.ssid })
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        database.savedWifiNetworks.remove(atOffsets: offsets)
                    }
                } header: {
                    Text("Saved networks")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a network"))
                }
            }
        }
        .navigationTitle("WiFi")
    }
}

private struct RtmpUrlAndImage {
    let url: String
    let image: String
}

private struct DjiDeviceRtmpSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsDjiDevice
    @ObservedObject var status: StatusOther
    @ObservedObject var rtmpServer: SettingsRtmpServer

    private func serverUrls() -> [RtmpUrlAndImage] {
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId) else {
            return []
        }
        var serverUrls: [RtmpUrlAndImage] = []
        for status in status.ipStatuses.filter({ $0.ipType == .ipv4 }) {
            serverUrls.append(RtmpUrlAndImage(url: rtmpServerStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: rtmpServer.port,
                streamKey: stream.streamKey
            ), image: urlImage(interfaceType: status.interfaceType)))
        }
        serverUrls.append(RtmpUrlAndImage(url: rtmpServerStreamUrl(
            address: personalHotspotLocalAddress,
            port: rtmpServer.port,
            streamKey: stream.streamKey
        ), image: "personalhotspot"))
        for status in status.ipStatuses.filter({ $0.ipType == .ipv6 }) {
            serverUrls.append(RtmpUrlAndImage(url: rtmpServerStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: rtmpServer.port,
                streamKey: stream.streamKey
            ), image: urlImage(interfaceType: status.interfaceType)))
        }
        if let serverRtmpUrl = device.serverRtmpUrl,
           !serverUrls.contains(where: { $0.url == serverRtmpUrl })
        {
            serverUrls.insert(RtmpUrlAndImage(url: serverRtmpUrl, image: "questionmark"), at: 0)
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
                        device.serverRtmpUrl = nil
                    }
                    .disabled(device.isStarted)
                    Picker("URL", selection: $device.serverRtmpUrl) {
                        Section("Auto IP address") {
                            HStack {
                                Image(systemName: "wifi")
                                Text(model.automaticServerRtmpUrl(device: device) ?? "")
                            }
                            .tag(nil as String?)
                        }
                        Section("Fixed IP address") {
                            ForEach(serverUrls(), id: \.url) { item in
                                HStack {
                                    Image(systemName: item.image)
                                    Text(item.url)
                                }
                                .tag(item.url as String?)
                            }
                        }
                    }
                    .disabled(device.isStarted)
                    if device.serverRtmpUrl == nil, !status.isConnectedToIpv4WiFi() {
                        Text("⚠️ Not connected to an IPv4 WiFi network.")
                    }
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
                if device.customRtmpUrl.isEmpty {
                    Text("⚠️ Enter the URL the DJI device should stream to.")
                }
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
            }
        }
        ShortcutSectionView {
            RtmpServerSettingsView(rtmpServer: rtmpServer)
        }
    }
}

private struct DjiDeviceSettingsSettingsView: View {
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
            if device.model.hasImageStabilization() {
                Picker("Image stabilization", selection: $device.imageStabilization) {
                    ForEach(SettingsDjiDeviceImageStabilization.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .disabled(device.isStarted)
            }
            if device.model == .osmoPocket3 || device.model == .osmoPocket4 {
                Picker("FPS", selection: $device.fps) {
                    ForEach(djiDeviceFpss, id: \.self) {
                        Text(String($0))
                    }
                }
                .disabled(device.isStarted)
            }
            if device.model.hasVideoCodec() {
                Picker("Video codec", selection: $device.videoCodec) {
                    ForEach(SettingsDjiDeviceVideoCodec.allCases, id: \.self) {
                        Text($0.rawValue)
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
    @ObservedObject var status: StatusOther
    @ObservedObject var device: SettingsDjiDevice

    var body: some View {
        if !device.isStarted {
            Section {
                TextButtonView("Start live stream") {
                    model.startDjiDeviceLiveStream(device: device)
                }
            }
            .disabled(!device.canStartLive(status.isConnectedToIpv4WiFi()))
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
        formatDjiDeviceState(state: status.djiDeviceStreamingState)
    }

    var body: some View {
        Form {
            Section {
                NameEditView(name: $device.name, existingNames: djiDevices.devices)
            }
            DjiDeviceSelectDeviceSettingsView(device: device)
            DjiDeviceWiFiSettingsView(model: model, device: device)
            DjiDeviceRtmpSettingsView(
                device: device,
                status: model.statusOther,
                rtmpServer: model.database.rtmpServer
            )
            DjiDeviceSettingsSettingsView(device: device)
            DjiDeviceAutoRestartSettingsView(device: device)
            Section {
                HCenter {
                    Text(state())
                }
            }
            DjiDeviceStartStopButtonSettingsView(status: model.statusOther, device: device)
        }
        .onAppear {
            model.setCurrentDjiDevice(device: device)
        }
        .navigationTitle("DJI device")
    }
}
