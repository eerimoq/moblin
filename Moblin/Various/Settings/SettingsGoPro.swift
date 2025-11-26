import Foundation

class SettingsGoProWifiCredentials: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My SSID")
    var id: UUID = .init()
    @Published var name = baseName
    @Published var ssid = ""
    @Published var password = ""

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             ssid,
             password
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.ssid, ssid)
        try container.encode(.password, password)
    }

    required init(from decoder: Decoder) throws {
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
        case id,
             name,
             type,
             serverStreamId,
             serverUrl,
             customUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.type, type)
        try container.encode(.serverStreamId, serverStreamId)
        try container.encode(.serverUrl, serverUrl)
        try container.encode(.customUrl, customUrl)
    }

    required init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
        self = try SettingsGoProLaunchLiveStreamResolution(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .r1080p
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
        case id,
             name,
             isHero12Or13,
             resolution
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.isHero12Or13, isHero12Or13)
        try container.encode(.resolution, resolution)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        isHero12Or13 = container.decode(.isHero12Or13, Bool.self, true)
        resolution = container.decode(.resolution, SettingsGoProLaunchLiveStreamResolution.self, .r1080p)
    }
}

class SettingsGoPro: Codable, ObservableObject {
    @Published var launchLiveStream: [SettingsGoProLaunchLiveStream] = []
    @Published var selectedLaunchLiveStream: UUID?
    @Published var wifiCredentials: [SettingsGoProWifiCredentials] = []
    @Published var selectedWifiCredentials: UUID?
    @Published var rtmpUrls: [SettingsGoProRtmpUrl] = []
    @Published var selectedRtmpUrl: UUID?

    init() {}

    enum CodingKeys: CodingKey {
        case launchLiveStream,
             selectedLaunchLiveStream,
             wifiCredentials,
             selectedWifiCredentials,
             rtmpUrls,
             selectedRtmpUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.launchLiveStream, launchLiveStream)
        try container.encode(.selectedLaunchLiveStream, selectedLaunchLiveStream)
        try container.encode(.wifiCredentials, wifiCredentials)
        try container.encode(.selectedWifiCredentials, selectedWifiCredentials)
        try container.encode(.rtmpUrls, rtmpUrls)
        try container.encode(.selectedRtmpUrl, selectedRtmpUrl)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchLiveStream = container.decode(.launchLiveStream, [SettingsGoProLaunchLiveStream].self, [])
        selectedLaunchLiveStream = try? container.decode(UUID.self, forKey: .selectedLaunchLiveStream)
        wifiCredentials = container.decode(.wifiCredentials, [SettingsGoProWifiCredentials].self, [])
        selectedWifiCredentials = try? container.decode(UUID.self, forKey: .selectedWifiCredentials)
        rtmpUrls = container.decode(.rtmpUrls, [SettingsGoProRtmpUrl].self, [])
        selectedRtmpUrl = try? container.decode(UUID.self, forKey: .selectedRtmpUrl)
    }
}
