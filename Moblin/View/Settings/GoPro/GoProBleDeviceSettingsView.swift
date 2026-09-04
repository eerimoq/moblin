import NetworkExtension
import SwiftUI

func formatGoProDeviceState(_ state: GoProDeviceState?) -> String {
    switch state {
    case nil, .idle:
        String(localized: "Not started")
    case .discovering:
        String(localized: "Discovering")
    case .connecting:
        String(localized: "Connecting")
    case .pairing:
        String(localized: "Pairing")
    case .settingUpWifi:
        String(localized: "Setting up WiFi")
    case .wifiSetupFailed:
        String(localized: "WiFi setup failed")
    case .configuring:
        String(localized: "Configuring")
    case .startingStream:
        String(localized: "Starting stream")
    case .streaming:
        String(localized: "Streaming")
    case .stoppingStream:
        String(localized: "Stopping stream")
    case .failed:
        String(localized: "Failed")
    }
}

private struct GoProDeviceScannerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject private var scanner: GoProDeviceScanner = .shared
    @Environment(\.dismiss) private var dismiss
    let onSelect: (GoProDiscoveredDevice) -> Void

    var body: some View {
        Form {
            Section {
                if !model.bluetoothAllowed {
                    Text(bluetoothNotAllowedMessage)
                } else if scanner.discoveredDevices.isEmpty {
                    HCenter {
                        ProgressView()
                    }
                } else {
                    ForEach(scanner.discoveredDevices, id: \.peripheral.identifier) { discoveredDevice in
                        Button(discoveredDevice.name) {
                            onSelect(discoveredDevice)
                            dismiss()
                        }
                    }
                }
            } footer: {
                Text(
                    "Put the GoPro in pairing mode, keep it nearby, and make sure GoPro Quik is disconnected."
                )
            }
        }
        .onAppear {
            scanner.startScanningForDevices()
        }
        .onDisappear {
            scanner.stopScanningForDevices()
        }
        .navigationTitle("GoPro camera")
    }
}

private struct GoProDeviceSelectionSection: View {
    @ObservedObject var device: SettingsGoProDevice

    var body: some View {
        Section("Camera") {
            NavigationLink {
                GoProDeviceScannerSettingsView { discoveredDevice in
                    device.bluetoothPeripheralId = discoveredDevice.peripheral.identifier
                    device.bluetoothPeripheralName = discoveredDevice.name
                }
            } label: {
                TextItemLocalizedView(
                    name: "Device",
                    value: device.bluetoothPeripheralName ?? String(localized: "Select device")
                )
            }
            .disabled(device.isStarted)
            if device.bluetoothPeripheralId == nil {
                Text("⚠️ Select a GoPro. The first connection requires pairing mode on the camera.")
            }
        }
    }
}

private struct GoProDeviceWifiSection: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsGoProDevice

    var body: some View {
        Section {
            TextEditNavigationView(
                title: String(localized: "SSID"),
                value: device.wifiSsid,
                onSubmit: {
                    device.wifiSsid = $0
                    if device.wifiPassword.isEmpty {
                        device.wifiPassword = model.database.getSavedWiFiNetwork(ssid: $0)?.password ?? ""
                    }
                }
            )
            .disabled(device.isStarted)
            TextEditNavigationView(
                title: String(localized: "Password"),
                value: device.wifiPassword,
                onSubmit: {
                    device.wifiPassword = $0
                    guard !device.wifiSsid.isEmpty else {
                        return
                    }
                    if let network = model.database.getSavedWiFiNetwork(ssid: device.wifiSsid) {
                        network.password = $0
                    } else {
                        let network = SettingsWiFi()
                        network.ssid = device.wifiSsid
                        network.password = $0
                        model.database.savedWifiNetworks.append(network)
                    }
                },
                sensitive: true
            )
            .disabled(device.isStarted)
            if device.wifiSsid.isEmpty {
                Text("⚠️ Enter the WiFi network the GoPro should use for streaming.")
            }
        } header: {
            Text("WiFi")
        } footer: {
            Text("Moblin sends these credentials securely to the paired GoPro over Bluetooth.")
        }
        .onAppear {
            NEHotspotNetwork.fetchCurrent { network in
                guard let ssid = network?.ssid else {
                    return
                }
                DispatchQueue.main.async {
                    if device.wifiSsid.isEmpty {
                        device.wifiSsid = ssid
                        device.wifiPassword = model.database.getSavedWiFiNetwork(ssid: ssid)?.password ?? ""
                    }
                }
            }
        }
    }
}

private struct GoProRtmpUrlAndImage {
    let url: String
    let image: String
}

private struct GoProDeviceRtmpSection: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsGoProDevice
    @ObservedObject var status: StatusOther
    @ObservedObject var rtmpServer: SettingsRtmpServer

    private func serverUrls() -> [GoProRtmpUrlAndImage] {
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId) else {
            return []
        }
        var urls = status.ipStatuses.map { status in
            GoProRtmpUrlAndImage(
                url: rtmpServerStreamUrl(
                    address: status.ipType.formatAddress(status.ip),
                    port: rtmpServer.port,
                    streamKey: stream.streamKey
                ),
                image: urlImage(interfaceType: status.interfaceType)
            )
        }
        urls.append(.init(
            url: rtmpServerStreamUrl(
                address: personalHotspotLocalAddress,
                port: rtmpServer.port,
                streamKey: stream.streamKey
            ),
            image: "personalhotspot"
        ))
        if let fixedUrl = device.serverRtmpUrl, !urls.contains(where: { $0.url == fixedUrl }) {
            urls.insert(.init(url: fixedUrl, image: "questionmark"), at: 0)
        }
        return urls
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
                            Text(stream.name).tag(stream.id)
                        }
                    }
                    .onChange(of: device.serverRtmpStreamId) { _ in
                        device.serverRtmpUrl = nil
                    }
                    .disabled(device.isStarted)
                    Picker("URL", selection: $device.serverRtmpUrl) {
                        Section("Auto IP address") {
                            Label(model.automaticServerRtmpUrl(device: device) ?? "", systemImage: "wifi")
                                .tag(nil as String?)
                        }
                        Section("Fixed IP address") {
                            ForEach(serverUrls(), id: \.url) { item in
                                Label(item.url, systemImage: item.image)
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
            } else {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: device.customRtmpUrl,
                    onSubmit: { device.customRtmpUrl = $0 }
                )
                .disabled(device.isStarted)
                if device.customRtmpUrl.isEmpty {
                    Text("⚠️ Enter the URL the GoPro should stream to.")
                }
            }
        } header: {
            Text("RTMP")
        } footer: {
            Text(
                "Select Server to stream into Moblin, or Custom to stream directly to another RTMP destination."
            )
        }
        .onAppear {
            if !rtmpServer.streams.isEmpty,
               !rtmpServer.streams.contains(where: { $0.id == device.serverRtmpStreamId })
            {
                device.serverRtmpStreamId = rtmpServer.streams.first!.id
            }
        }
        ShortcutSectionView {
            RtmpServerSettingsView(rtmpServer: rtmpServer)
        }
    }
}

private struct GoProDeviceStreamSettingsSection: View {
    @ObservedObject var device: SettingsGoProDevice

    var body: some View {
        Section("Stream settings") {
            Picker("Resolution", selection: $device.resolution) {
                ForEach(SettingsGoProLaunchLiveStreamResolution.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .disabled(device.isStarted)
            Picker("Maximum bitrate", selection: $device.bitrate) {
                ForEach(goProDeviceBitrates, id: \.self) {
                    Text(formatBytesPerSecond(speed: Int64($0)))
                }
            }
            .disabled(device.isStarted)
            Picker("Lens", selection: $device.lens) {
                ForEach(SettingsGoProLens.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .disabled(device.isStarted)
            if device.rtmpUrlType == .server {
                Toggle("Auto-restart live stream when broken", isOn: $device.autoRestartStream)
            }
        }
    }
}

private struct GoProDeviceStartStopSection: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsGoProDevice
    @ObservedObject var status: StatusOther

    var body: some View {
        if device.isStarted {
            Section {
                TextButtonView("Stop live stream") {
                    model.stopGoProDeviceLiveStream(device: device)
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.blue)
        } else {
            Section {
                TextButtonView("Start live stream") {
                    model.startGoProDeviceLiveStream(device: device)
                }
            }
            .disabled(!device.canStartLive(status.isConnectedToIpv4WiFi()))
        }
    }
}

private struct GoProBleDeviceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var device: SettingsGoProDevice

    var body: some View {
        Form {
            Section {
                NameEditView(name: $device.name, existingNames: model.database.goPro.devices)
            }
            GoProDeviceSelectionSection(device: device)
            GoProDeviceWifiSection(device: device)
            GoProDeviceRtmpSection(
                device: device,
                status: model.statusOther,
                rtmpServer: model.database.rtmpServer
            )
            GoProDeviceStreamSettingsSection(device: device)
            Section {
                HCenter {
                    Text(formatGoProDeviceState(device.state))
                }
            }
            GoProDeviceStartStopSection(device: device, status: model.statusOther)
        }
        .navigationTitle("GoPro camera")
    }
}

struct GoProBleDevicesSettingsSection: View {
    @EnvironmentObject var model: Model
    @ObservedObject var goPro: SettingsGoPro

    var body: some View {
        Section {
            ForEach(goPro.devices) { device in
                NavigationLink {
                    GoProBleDeviceSettingsView(device: device)
                } label: {
                    HStack {
                        DraggableItemPrefixView()
                        Text(device.name)
                        Spacer()
                        GrayTextView(text: formatGoProDeviceState(device.state))
                    }
                }
                .contextMenuDeleteButton {
                    if let offsets = makeOffsets(goPro.devices, device.id) {
                        model.removeGoProDevices(offsets: offsets)
                    }
                }
            }
            .onMove { from, to in
                goPro.devices.move(fromOffsets: from, toOffset: to)
            }
            .onDelete(perform: model.removeGoProDevices)
            CreateButtonView {
                let device = SettingsGoProDevice()
                device.name = makeUniqueName(name: SettingsGoProDevice.baseName, existingNames: goPro.devices)
                goPro.devices.append(device)
            }
        } header: {
            Text("Bluetooth cameras")
        } footer: {
            Text(
                "Pair and control compatible GoPro cameras over Bluetooth. HERO9 Black or newer is required."
            )
        }
    }
}
