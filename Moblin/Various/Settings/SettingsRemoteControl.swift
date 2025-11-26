import Foundation

class SettingsRemoteControlAssistant: Codable, ObservableObject, Identifiable, Named {
    static let baseName = String(localized: "Streamer name")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 0
    var relay: SettingsRemoteControlServerRelay = .init()

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             port,
             relay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.relay, relay)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 0)
        relay = container.decode(.relay, SettingsRemoteControlServerRelay.self, .init())
    }
}

class SettingsRemoteControlStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var url: String = ""
    @Published var previewFps: Float = 1.0

    enum CodingKeys: CodingKey {
        case enabled,
             url,
             previewFps
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.previewFps, previewFps)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        url = container.decode(.url, String.self, "")
        previewFps = container.decode(.previewFps, Float.self, 1.0)
    }
}

class SettingsRemoteControlServerRelay: Codable, ObservableObject {
    @Published var enabled: Bool = true
    @Published var baseUrl: String = "wss://moblin.mys-lang.org/moblin-remote-control-relay"
    @Published var bridgeId: String = UUID().uuidString.lowercased()

    enum CodingKeys: CodingKey {
        case enabled,
             baseUrl,
             bridgeId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.baseUrl, baseUrl)
        try container.encode(.bridgeId, bridgeId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        baseUrl = container.decode(.baseUrl, String.self, "wss://moblin.mys-lang.org/moblin-remote-control-relay")
        bridgeId = container.decode(.bridgeId, String.self, UUID().uuidString.lowercased())
    }
}

class SettingsRemoteControl: Codable, ObservableObject {
    var assistant: SettingsRemoteControlAssistant = .init()
    var streamer: SettingsRemoteControlStreamer = .init()
    var password: String = randomGoodPassword()
    @Published var streamers: [SettingsRemoteControlAssistant] = []
    @Published var selectedStreamer: UUID?
    var hasMigratedAssistant: Bool = true

    enum CodingKeys: CodingKey {
        case client,
             server,
             password,
             streamers,
             selectedStreamer,
             hasMigratedAssistant
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.client, assistant)
        try container.encode(.server, streamer)
        try container.encode(.password, password)
        try container.encode(.streamers, streamers)
        try container.encode(.selectedStreamer, selectedStreamer)
        try container.encode(.hasMigratedAssistant, hasMigratedAssistant)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistant = container.decode(.client, SettingsRemoteControlAssistant.self, .init())
        streamer = container.decode(.server, SettingsRemoteControlStreamer.self, .init())
        password = container.decode(.password, String.self, randomGoodPassword())
        streamers = container.decode(.streamers, [SettingsRemoteControlAssistant].self, [])
        selectedStreamer = container.decode(.selectedStreamer, UUID?.self, nil)
        hasMigratedAssistant = container.decode(.hasMigratedAssistant, Bool.self, false)
        if !hasMigratedAssistant {
            let streamer = SettingsRemoteControlAssistant()
            streamer.name = "Streamer"
            streamer.enabled = assistant.enabled
            streamer.port = assistant.port
            streamer.relay.enabled = assistant.relay.enabled
            streamer.relay.baseUrl = assistant.relay.baseUrl
            streamer.relay.bridgeId = assistant.relay.bridgeId
            streamers.append(streamer)
            selectedStreamer = streamer.id
            hasMigratedAssistant = true
        }
    }

    func getSelectedStreamerName() -> String? {
        return streamers.first(where: { $0.id == selectedStreamer })?.name
    }
}
