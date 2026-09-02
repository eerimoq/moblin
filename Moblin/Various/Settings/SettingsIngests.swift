import Foundation

private let defaultRtmpLatency: Int32 = 2000

class SettingsRtmpServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamKey: String = ""
    @Published var latency: Int32 = defaultRtmpLatency
    @Published var intrinsicDelay: Int32 = 0
    @Published var trackDrift: Bool = true

    enum CodingKeys: CodingKey {
        case id
        case name
        case streamKey
        case latency
        case intrinsicDelay
        case trackDrift
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamKey, streamKey)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
        try container.encode(.trackDrift, trackDrift)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamKey = container.decode(.streamKey, String.self, "")
        latency = container.decode(.latency, Int32.self, defaultRtmpLatency)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
        trackDrift = container.decode(.trackDrift, Bool.self, true)
    }

    func camera() -> String {
        rtmpCamera(name: name)
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func clone() -> SettingsRtmpServerStream {
        let new = SettingsRtmpServerStream()
        new.id = id
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        new.intrinsicDelay = intrinsicDelay
        new.trackDrift = trackDrift
        return new
    }
}

class SettingsRtmpServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = DefaultTcpPorts.rtmpServer
    @Published var streams: [SettingsRtmpServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled
        case port
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, DefaultTcpPorts.rtmpServer)
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
    @Published var latency: Int32 = 500
    @Published var intrinsicDelay: Int32 = 0

    enum CodingKeys: CodingKey {
        case id
        case name
        case streamId
        case latency
        case intrinsicDelay
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamId, streamId)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamId = container.decode(.streamId, String.self, "")
        latency = container.decode(.latency, Int32.self, 500)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
    }

    func camera() -> String {
        srtlaCamera(name: name)
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func clone() -> SettingsSrtlaServerStream {
        let new = SettingsSrtlaServerStream()
        new.id = id
        new.name = name
        new.streamId = streamId
        new.latency = latency
        new.intrinsicDelay = intrinsicDelay
        return new
    }
}

class SettingsSrtlaServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var srtPort: UInt16 = DefaultUdpPorts.srtServer
    @Published var srtlaPort: UInt16 = DefaultUdpPorts.srtlaServer
    @Published var streams: [SettingsSrtlaServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled
        case srtPort
        case srtlaPort
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.srtPort, srtPort)
        try container.encode(.srtlaPort, srtlaPort)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        srtPort = container.decode(.srtPort, UInt16.self, DefaultUdpPorts.srtServer)
        srtlaPort = container.decode(.srtlaPort, UInt16.self, DefaultUdpPorts.srtlaServer)
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
        srtlaPort + 1
    }
}

class SettingsSrtClientStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = ""
    @Published var enabled: Bool = false
    @Published var latency: Int32 = 500
    @Published var intrinsicDelay: Int32 = 0

    enum CodingKeys: CodingKey {
        case id
        case name
        case url
        case enabled
        case latency
        case intrinsicDelay
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        latency = container.decode(.latency, Int32.self, 500)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
    }

    func camera() -> String {
        srtClientCamera(name: name)
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }
}

class SettingsSrtClient: Codable, ObservableObject {
    @Published var streams: [SettingsSrtClientStream] = []

    enum CodingKeys: CodingKey {
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsSrtClientStream].self, [])
    }
}

class SettingsRistServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var virtualDestinationPort: UInt16 = 1
    @Published var latency: Int32 = 2000
    @Published var intrinsicDelay: Int32 = 0
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id
        case name
        case virtualDestinationPort
        case latency
        case intrinsicDelay
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.virtualDestinationPort, virtualDestinationPort)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        virtualDestinationPort = container.decode(.virtualDestinationPort, UInt16.self, 1)
        latency = container.decode(.latency, Int32.self, 2000)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func clone() -> SettingsRistServerStream {
        let new = SettingsRistServerStream()
        new.name = name
        new.virtualDestinationPort = virtualDestinationPort
        new.latency = latency
        new.intrinsicDelay = intrinsicDelay
        return new
    }

    func camera() -> String {
        ristCamera(name: name)
    }
}

class SettingsRistServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = DefaultUdpPorts.ristServer
    @Published var streams: [SettingsRistServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled
        case port
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, DefaultUdpPorts.ristServer)
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

enum SettingsRtspTransport: String, Codable, CaseIterable {
    case rtpRtspTcp
    case rtpUdp

    func toString() -> String {
        switch self {
        case .rtpRtspTcp:
            "RTP/RTSP/TCP"
        case .rtpUdp:
            "RTP/UDP"
        }
    }
}

class SettingsRtspClientStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = ""
    @Published var enabled: Bool = false
    @Published var latency: Int32 = 2000
    @Published var intrinsicDelay: Int32 = 0
    @Published var transport: SettingsRtspTransport = .rtpRtspTcp

    enum CodingKeys: CodingKey {
        case id
        case name
        case url
        case enabled
        case latency
        case intrinsicDelay
        case transport
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
        try container.encode(.transport, transport)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        latency = container.decode(.latency, Int32.self, 2000)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
        transport = container.decode(.transport, SettingsRtspTransport.self, .rtpRtspTcp)
    }

    func camera() -> String {
        rtspCamera(name: name)
    }
}

class SettingsRtspClient: Codable, ObservableObject {
    @Published var streams: [SettingsRtspClientStream] = []

    enum CodingKeys: CodingKey {
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsRtspClientStream].self, [])
    }
}

class SettingsWhipServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamKey: String = ""
    @Published var latency: Int32 = 100
    @Published var intrinsicDelay: Int32 = 0
    @Published var syncTimestamps: Bool = true

    enum CodingKeys: CodingKey {
        case id
        case name
        case streamKey
        case latency
        case intrinsicDelay
        case syncTimestamps
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamKey, streamKey)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
        try container.encode(.syncTimestamps, syncTimestamps)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamKey = container.decode(.streamKey, String.self, "")
        latency = container.decode(.latency, Int32.self, 100)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
        syncTimestamps = container.decode(.syncTimestamps, Bool.self, true)
    }

    func camera() -> String {
        whipCamera(name: name)
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func clone() -> SettingsWhipServerStream {
        let new = SettingsWhipServerStream()
        new.id = id
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        new.intrinsicDelay = intrinsicDelay
        new.syncTimestamps = syncTimestamps
        return new
    }
}

class SettingsWhipServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = DefaultTcpPorts.whipServer
    @Published var streams: [SettingsWhipServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled
        case port
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, DefaultTcpPorts.whipServer)
        streams = container.decode(.streams, [SettingsWhipServerStream].self, [])
    }

    func clone() -> SettingsWhipServer {
        let new = SettingsWhipServer()
        new.enabled = enabled
        new.port = port
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }
}

class SettingsWhepClientStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = ""
    @Published var enabled: Bool = false
    @Published var latency: Int32 = 100
    @Published var intrinsicDelay: Int32 = 0
    @Published var syncTimestamps: Bool = true

    enum CodingKeys: CodingKey {
        case id
        case name
        case url
        case enabled
        case latency
        case intrinsicDelay
        case syncTimestamps
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func intrinsicDelaySeconds() -> Double {
        Double(intrinsicDelay) / 1000
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
        try container.encode(.latency, latency)
        try container.encode(.intrinsicDelay, intrinsicDelay)
        try container.encode(.syncTimestamps, syncTimestamps)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        latency = container.decode(.latency, Int32.self, 100)
        intrinsicDelay = container.decode(.intrinsicDelay, Int32.self, 0)
        syncTimestamps = container.decode(.syncTimestamps, Bool.self, true)
    }

    func camera() -> String {
        whepCamera(name: name)
    }
}

class SettingsWhepClient: Codable, ObservableObject {
    @Published var streams: [SettingsWhepClientStream] = []

    enum CodingKeys: CodingKey {
        case streams
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsWhepClientStream].self, [])
    }
}
