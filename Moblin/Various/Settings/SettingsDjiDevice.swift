import Foundation

enum SettingsDjiDeviceUrlType: String, Codable, CaseIterable {
    case server = "Server"
    case custom = "Custom"

    init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceUrlType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .server
    }

    func toString() -> String {
        switch self {
        case .server:
            return String(localized: "Server")
        case .custom:
            return String(localized: "Custom")
        }
    }
}

enum SettingsDjiDeviceImageStabilization: String, CaseIterable, Codable {
    case off
    case rockSteady
    case rockSteadyPlus
    case horizonBalancing
    case horizonSteady

    init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceImageStabilization(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .rockSteady
    }

    func toString() -> String {
        switch self {
        case .off:
            return String(localized: "Off")
        case .rockSteady:
            return String(localized: "RockSteady")
        case .rockSteadyPlus:
            return String(localized: "RockSteady+")
        case .horizonBalancing:
            return String(localized: "HorizonBalancing")
        case .horizonSteady:
            return String(localized: "HorizonSteady")
        }
    }
}

enum SettingsDjiDeviceResolution: String, CaseIterable, Codable {
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"

    init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceResolution(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .r1080p
    }
}

enum SettingsDjiDeviceModel: String, Codable {
    case osmoAction3
    case osmoAction4
    case osmoAction5Pro
    case osmoAction6
    case osmoPocket3
    case unknown

    init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceModel(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .unknown
    }
}

var djiDeviceBitrates: [UInt32] = [
    20_000_000,
    16_000_000,
    12_000_000,
    10_000_000,
    8_000_000,
    6_000_000,
    4_000_000,
    2_000_000,
]

var djiDeviceFpss: [Int] = [25, 30]

class SettingsDjiDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var wifiSsid: String = ""
    @Published var wifiPassword: String = ""
    @Published var rtmpUrlType: SettingsDjiDeviceUrlType = .server
    @Published var serverRtmpStreamId: UUID = .init()
    @Published var serverRtmpUrl: String = ""
    @Published var customRtmpUrl: String = ""
    @Published var autoRestartStream: Bool = false
    @Published var imageStabilization: SettingsDjiDeviceImageStabilization = .off
    @Published var resolution: SettingsDjiDeviceResolution = .r1080p
    @Published var fps: Int = 30
    @Published var bitrate: UInt32 = 6_000_000
    @Published var isStarted: Bool = false
    @Published var model: SettingsDjiDeviceModel = .unknown
    @Published var state: DjiDeviceState?

    init() {
        bluetoothPeripheralName = nil
        bluetoothPeripheralId = nil
    }

    enum CodingKeys: CodingKey {
        case id,
             name,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             wifiSsid,
             wifiPassword,
             rtmpUrlType,
             serverRtmpStreamId,
             serverRtmpUrl,
             customRtmpUrl,
             autoRestartStream,
             imageStabilization,
             resolution,
             fps,
             bitrate,
             isStarted,
             model
    }

    func encode(to encoder: Encoder) throws {
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
        try container.encode(.autoRestartStream, autoRestartStream)
        try container.encode(.imageStabilization, imageStabilization)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.isStarted, isStarted)
        try container.encode(.model, model)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        wifiSsid = container.decode(.wifiSsid, String.self, "")
        wifiPassword = container.decode(.wifiPassword, String.self, "")
        rtmpUrlType = container.decode(.rtmpUrlType, SettingsDjiDeviceUrlType.self, .server)
        serverRtmpStreamId = container.decode(.serverRtmpStreamId, UUID.self, .init())
        serverRtmpUrl = container.decode(.serverRtmpUrl, String.self, "")
        customRtmpUrl = container.decode(.customRtmpUrl, String.self, "")
        autoRestartStream = container.decode(.autoRestartStream, Bool.self, false)
        imageStabilization = container.decode(.imageStabilization, SettingsDjiDeviceImageStabilization.self, .off)
        resolution = container.decode(.resolution, SettingsDjiDeviceResolution.self, .r1080p)
        fps = container.decode(.fps, Int.self, 30)
        bitrate = container.decode(.bitrate, UInt32.self, 6_000_000)
        isStarted = container.decode(.isStarted, Bool.self, false)
        model = container.decode(.model, SettingsDjiDeviceModel.self, .unknown)
    }
}

class SettingsDjiDevices: Codable, ObservableObject {
    @Published var devices: [SettingsDjiDevice] = []

    init() {}

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsDjiDevice].self, [])
    }
}
