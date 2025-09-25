import Foundation

private let defaultRtmpLatency: Int32 = 2000

class SettingsRtmpServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamKey: String = ""
    @Published var latency: Int32 = defaultRtmpLatency
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             streamKey,
             latency
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamKey, streamKey)
        try container.encode(.latency, latency)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamKey = container.decode(.streamKey, String.self, "")
        latency = container.decode(.latency, Int32.self, defaultRtmpLatency)
    }

    func camera() -> String {
        return rtmpCamera(name: name)
    }

    func clone() -> SettingsRtmpServerStream {
        let new = SettingsRtmpServerStream()
        new.id = id
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        return new
    }
}

class SettingsRtmpServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 1935
    @Published var streams: [SettingsRtmpServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             port,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 1935)
        streams = container.decode(.streams, [SettingsRtmpServerStream].self, [])
    }

    func clone() -> SettingsRtmpServer {
        let new = SettingsRtmpServer()
        new.enabled = enabled
        new.port = port
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }
}

class SettingsSrtlaServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamId: String = ""
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             streamId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamId, streamId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamId = container.decode(.streamId, String.self, "")
    }

    func camera() -> String {
        return srtlaCamera(name: name)
    }

    func clone() -> SettingsSrtlaServerStream {
        let new = SettingsSrtlaServerStream()
        new.name = name
        new.streamId = streamId
        return new
    }
}

class SettingsSrtlaServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var srtPort: UInt16 = 4000
    @Published var srtlaPort: UInt16 = 5000
    @Published var streams: [SettingsSrtlaServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             srtPort,
             srtlaPort,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.srtPort, srtPort)
        try container.encode(.srtlaPort, srtlaPort)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        srtPort = container.decode(.srtPort, UInt16.self, 4000)
        srtlaPort = container.decode(.srtlaPort, UInt16.self, 5000)
        streams = container.decode(.streams, [SettingsSrtlaServerStream].self, [])
    }

    func clone() -> SettingsSrtlaServer {
        let new = SettingsSrtlaServer()
        new.enabled = enabled
        new.srtPort = srtPort
        new.srtlaPort = srtlaPort
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }

    func srtlaSrtPort() -> UInt16 {
        return srtlaPort + 1
    }
}

class SettingsRistServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var virtualDestinationPort: UInt16 = 1
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             virtualDestinationPort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.virtualDestinationPort, virtualDestinationPort)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        virtualDestinationPort = container.decode(.virtualDestinationPort, UInt16.self, 1)
    }

    func camera() -> String {
        return ristCamera(name: name)
    }
}

class SettingsRistServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 6500
    @Published var streams: [SettingsRistServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             port,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 6500)
        streams = container.decode(.streams, [SettingsRistServerStream].self, [])
    }

    func makeUniqueVirtualDestinationPort() -> UInt16 {
        var port: UInt16 = 1
        while streams.contains(where: { $0.virtualDestinationPort == port }) {
            port += 1
        }
        return port
    }
}

class SettingsRtspClientStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = ""
    @Published var enabled: Bool = false
    @Published var latency: Int32 = 2000

    enum CodingKeys: CodingKey {
        case id,
             name,
             url,
             enabled,
             latency
    }

    func latencySeconds() -> Double {
        return Double(latency) / 1000
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
        try container.encode(.latency, latency)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        latency = container.decode(.latency, Int32.self, 2000)
    }

    func camera() -> String {
        return rtspCamera(name: name)
    }
}

class SettingsRtspClient: Codable, ObservableObject {
    @Published var streams: [SettingsRtspClientStream] = []

    enum CodingKeys: CodingKey {
        case streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsRtspClientStream].self, [])
    }
}
