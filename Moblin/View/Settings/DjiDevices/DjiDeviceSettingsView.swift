import CoreLocation
import NetworkExtension
import SwiftUI

private final class WiFiSsidFetcher: NSObject, CLLocationManagerDelegate, ObservableObject {
    enum Failure: Error {
        case notConnected
        case locationDenied
    }

    private let manager = CLLocationManager()
    private var pending: ((Result<String, Failure>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func fetch(completion: @escaping (Result<String, Failure>) -> Void) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            performFetch(completion: completion)
        case .notDetermined:
            pending = completion
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion(.failure(.locationDenied))
        @unknown default:
            completion(.failure(.locationDenied))
        }
    }

    private func performFetch(completion: @escaping (Result<String, Failure>) -> Void) {
        NEHotspotNetwork.fetchCurrent { network in
            DispatchQueue.main.async {
                if let ssid = network?.ssid, !ssid.isEmpty {
                    completion(.success(ssid))
                } else {
                    completion(.failure(.notConnected))
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let pending else {
            return
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.pending = nil
            performFetch(completion: pending)
        case .denied, .restricted:
            self.pending = nil
            pending(.failure(.locationDenied))
        default:
            break
        }
    }
}

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
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
    @EnvironmentObject var model: Model
    @ObservedObject var djiDevices: SettingsDjiDevices
    @ObservedObject var device: SettingsDjiDevice
    @StateObject private var ssidFetcher = WiFiSsidFetcher()

    private func reusedPassword(forSsid ssid: String) -> String? {
        djiDevices.devices
            .first(where: { $0.id != device.id && $0.wifiSsid == ssid && !$0.wifiPassword.isEmpty })?
            .wifiPassword
    }

    private func selectMatchingRtmpUrl() {
        guard device.rtmpUrlType == .server else {
            return
        }
        guard let stream = model.getRtmpStream(id: device.serverRtmpStreamId) else {
            return
        }
        guard let wifiStatus = model.statusOther.ipStatuses.first(where: {
            $0.interfaceType == .wifi && $0.ipType == .ipv4
        }) else {
            return
        }
        device.serverRtmpUrl = rtmpStreamUrl(
            address: wifiStatus.ipType.formatAddress(wifiStatus.ip),
            port: model.database.rtmpServer.port,
            streamKey: stream.streamKey
        )
    }

    private func applyImportedSsid(_ ssid: String) {
        if device.wifiSsid != ssid {
            device.wifiPassword = ""
        }
        device.wifiSsid = ssid
        selectMatchingRtmpUrl()
        if device.wifiPassword.isEmpty, let reused = reusedPassword(forSsid: ssid) {
            device.wifiPassword = reused
            model.makeToast(
                title: String(localized: "Imported \(ssid)"),
                subTitle: String(localized: "Password reused from another DJI device.")
            )
            return
        }
        if device.wifiPassword.isEmpty {
            model.makeToast(
                title: String(localized: "Imported \(ssid)"),
                subTitle: String(
                    localized:
                    "Enter the Wi-Fi password manually — iOS does not expose it to apps."
                )
            )
        } else {
            model.makeToast(title: String(localized: "Imported \(ssid)"))
        }
    }

    private func importCurrentWifi() {
        ssidFetcher.fetch { result in
            switch result {
            case let .success(ssid):
                applyImportedSsid(ssid)
            case .failure(.notConnected):
                model.makeErrorToast(
                    title: String(localized: "Not connected to a Wi-Fi network")
                )
            case .failure(.locationDenied):
                model.makeErrorToast(
                    title: String(localized: "Location permission required"),
                    subTitle: String(
                        localized:
                        "iOS requires location access to read the Wi-Fi SSID. Enable it in Settings → Moblin → Location"
                    )
                )
            }
        }
    }

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
                TextItemLocalizedView(name: "SSID", value: device.wifiSsid)
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
                TextItemLocalizedView(name: "Password", value: device.wifiPassword, sensitive: true)
            }
            .disabled(device.isStarted)
            TextButtonView("Use current Wi-Fi") {
                importCurrentWifi()
            }
            .disabled(device.isStarted)
            if device.wifiSsid.isEmpty {
                Text("⚠️ Enter the SSID of the network the DJI device should connect to.")
            }
        } header: {
            Text("WiFi")
        } footer: {
            Text("The DJI device will connect to and stream RTMP over this WiFi.")
        }
        .onAppear {
            guard device.wifiSsid.isEmpty else {
                return
            }
            NEHotspotNetwork.fetchCurrent { network in
                guard let ssid = network?.ssid else {
                    return
                }
                DispatchQueue.main.async {
                    if device.wifiSsid.isEmpty {
                        device.wifiSsid = ssid
                        if device.wifiPassword.isEmpty,
                           let reused = reusedPassword(forSsid: ssid)
                        {
                            device.wifiPassword = reused
                        }
                    }
                }
            }
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
        if let serverRtmpUrl = device.serverRtmpUrl, !serverUrls.contains(serverRtmpUrl) {
            serverUrls.insert(serverRtmpUrl, at: 0)
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
                        Text("-- None --")
                            .tag(nil as String?)
                        ForEach(serverUrls(), id: \.self) {
                            Text($0)
                                .tag($0 as String?)
                        }
                    }
                    .disabled(device.isStarted)
                    if device.serverRtmpUrl == nil {
                        Text("⚠️ Select the URL the DJI device should stream to.")
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
            if device.model.hasImageStabilizatin() {
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
        formatDjiDeviceState(state: status.djiDeviceStreamingState)
    }

    var body: some View {
        Form {
            Section {
                NameEditView(name: $device.name, existingNames: djiDevices.devices)
            }
            DjiDeviceSelectDeviceSettingsView(device: device)
            DjiDeviceWiFiSettingsView(djiDevices: djiDevices, device: device)
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
            DjiDeviceStartStopButtonSettingsView(device: device)
        }
        .onAppear {
            model.setCurrentDjiDevice(device: device)
        }
        .navigationTitle("DJI device")
    }
}
