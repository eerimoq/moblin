import Foundation

class SettingsGoProWifiCredentials: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My SSID")
    var id: UUID = .init()
    @Published var name = baseName
    @Published var ssid = ""
    @Published var password = ""

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case name
        case ssid
        case password
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.ssid, ssid)
        try container.encode(.password, password)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        ssid = container.decode(.ssid, String.self, "")
        password = container.decode(.password, String.self, "")
    }
}

class SettingsGoProRtmpUrl: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My URL")
    var id: UUID = .init()
    @Published var name = baseName
    @Published var type: SettingsDjiDeviceUrlType = .server
    @Published var serverStreamId: UUID = .init()
    @Published var serverUrl = ""
    @Published var customUrl = ""

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case name
        case type
        case serverStreamId
        case serverUrl
        case customUrl
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.type, type)
        try container.encode(.serverStreamId, serverStreamId)
        try container.encode(.serverUrl, serverUrl)
        try container.encode(.customUrl, customUrl)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        type = container.decode(.type, SettingsDjiDeviceUrlType.self, .server)
        serverStreamId = container.decode(.serverStreamId, UUID.self, .init())
        serverUrl = container.decode(.serverUrl, String.self, "")
        customUrl = container.decode(.customUrl, String.self, "")
    }
}

enum SettingsGoProLaunchLiveStreamResolution: String, CaseIterable, Codable {
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"
}

enum SettingsGoProLens: String, CaseIterable, Codable {
    case auto = "Auto"
    case wide = "Wide"
    case linear = "Linear"
    case superView = "SuperView"

    func toString() -> String {
        switch self {
        case .auto:
            String(localized: "Default")
        case .wide:
            String(localized: "Wide")
        case .linear:
            String(localized: "Linear")
        case .superView:
            String(localized: "SuperView")
        }
    }
}

let goProDeviceBitrates: [UInt32] = [
    8_000_000,
    6_000_000,
    4_000_000,
    2_000_000,
    1_000_000,
    800_000,
]

class SettingsGoProDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My GoPro")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var wifiSsid: String = ""
    @Published var wifiPassword: String = ""
    @Published var rtmpUrlType: SettingsDjiDeviceUrlType = .server
    @Published var serverRtmpStreamId: UUID = .init()
    @Published var serverRtmpUrl: String?
    @Published var customRtmpUrl: String = ""
    @Published var resolution: SettingsGoProLaunchLiveStreamResolution = .r1080p
    @Published var bitrate: UInt32 = 6_000_000
    @Published var lens: SettingsGoProLens = .auto
    @Published var autoRestartStream: Bool = false
    @Published var isStarted: Bool = false
    @Published var state: GoProDeviceState?

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case name
        case bluetoothPeripheralName
        case bluetoothPeripheralId
        case wifiSsid
        case wifiPassword
        case rtmpUrlType
        case serverRtmpStreamId
        case serverRtmpUrl
        case customRtmpUrl
        case resolution
        case bitrate
        case lens
        case autoRestartStream
        case isStarted
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.wifiSsid, wifiSsid)
        try container.encode(.wifiPassword, wifiPassword)
        try container.encode(.rtmpUrlType, rtmpUrlType)
        try container.encode(.serverRtmpStreamId, serverRtmpStreamId)
        try container.encode(.serverRtmpUrl, serverRtmpUrl)
        try container.encode(.customRtmpUrl, customRtmpUrl)
        try container.encode(.resolution, resolution)
        try container.encode(.bitrate, bitrate)
        try container.encode(.lens, lens)
        try container.encode(.autoRestartStream, autoRestartStream)
        try container.encode(.isStarted, isStarted)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        wifiSsid = container.decode(.wifiSsid, String.self, "")
        wifiPassword = container.decode(.wifiPassword, String.self, "")
        rtmpUrlType = container.decode(.rtmpUrlType, SettingsDjiDeviceUrlType.self, .server)
        serverRtmpStreamId = container.decode(.serverRtmpStreamId, UUID.self, .init())
        serverRtmpUrl = container.decode(.serverRtmpUrl, String?.self, nil)
        customRtmpUrl = container.decode(.customRtmpUrl, String.self, "")
        resolution = container.decode(.resolution, SettingsGoProLaunchLiveStreamResolution.self, .r1080p)
        bitrate = container.decode(.bitrate, UInt32.self, 6_000_000)
        lens = container.decode(.lens, SettingsGoProLens.self, .auto)
        autoRestartStream = container.decode(.autoRestartStream, Bool.self, false)
        isStarted = container.decode(.isStarted, Bool.self, false)
    }

    func canStartLive(_ isConnectedToIpv4WiFi: Bool) -> Bool {
        guard bluetoothPeripheralId != nil, !wifiSsid.isEmpty else {
            return false
        }
        switch rtmpUrlType {
        case .server:
            if let serverRtmpUrl {
                return !serverRtmpUrl.isEmpty
            }
            return isConnectedToIpv4WiFi
        case .custom:
            return !customRtmpUrl.isEmpty
        }
    }
}

class SettingsGoProLaunchLiveStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My live")
    var id: UUID = .init()
    @Published var name = baseName
    @Published var isHero12Or13: Bool = true
    @Published var resolution: SettingsGoProLaunchLiveStreamResolution = .r1080p

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case name
        case isHero12Or13
        case resolution
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.isHero12Or13, isHero12Or13)
        try container.encode(.resolution, resolution)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        isHero12Or13 = container.decode(.isHero12Or13, Bool.self, true)
        resolution = container.decode(.resolution, SettingsGoProLaunchLiveStreamResolution.self, .r1080p)
    }
}

class SettingsGoPro: Codable, ObservableObject {
    @Published var devices: [SettingsGoProDevice] = []
    @Published var launchLiveStream: [SettingsGoProLaunchLiveStream] = []
    @Published var selectedLaunchLiveStream: UUID?
    @Published var wifiCredentials: [SettingsGoProWifiCredentials] = []
    @Published var selectedWifiCredentials: UUID?
    @Published var rtmpUrls: [SettingsGoProRtmpUrl] = []
    @Published var selectedRtmpUrl: UUID?

    init() {}

    enum CodingKeys: CodingKey {
        case devices
        case launchLiveStream
        case selectedLaunchLiveStream
        case wifiCredentials
        case selectedWifiCredentials
        case rtmpUrls
        case selectedRtmpUrl
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
        try container.encode(.launchLiveStream, launchLiveStream)
        try container.encode(.selectedLaunchLiveStream, selectedLaunchLiveStream)
        try container.encode(.wifiCredentials, wifiCredentials)
        try container.encode(.selectedWifiCredentials, selectedWifiCredentials)
        try container.encode(.rtmpUrls, rtmpUrls)
        try container.encode(.selectedRtmpUrl, selectedRtmpUrl)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsGoProDevice].self, [])
        launchLiveStream = container.decode(.launchLiveStream, [SettingsGoProLaunchLiveStream].self, [])
        selectedLaunchLiveStream = try? container.decode(UUID.self, forKey: .selectedLaunchLiveStream)
        wifiCredentials = container.decode(.wifiCredentials, [SettingsGoProWifiCredentials].self, [])
        selectedWifiCredentials = try? container.decode(UUID.self, forKey: .selectedWifiCredentials)
        rtmpUrls = container.decode(.rtmpUrls, [SettingsGoProRtmpUrl].self, [])
        selectedRtmpUrl = try? container.decode(UUID.self, forKey: .selectedRtmpUrl)
    }
}
