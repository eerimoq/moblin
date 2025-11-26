import Foundation

class SettingsMoblinkStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 7777

    enum CodingKeys: CodingKey {
        case enabled,
             port
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 7777)
    }
}

class SettingsMoblinkRelay: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var name: String = randomName()
    @Published var url: String = ""
    @Published var manual: Bool = false

    enum CodingKeys: CodingKey {
        case enabled,
             name,
             url,
             manual
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.manual, manual)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        name = container.decode(.name, String.self, randomName())
        url = container.decode(.url, String.self, "")
        manual = container.decode(.manual, Bool.self, false)
    }
}

class SettingsMoblink: Codable {
    var streamer: SettingsMoblinkStreamer = .init()
    var relay: SettingsMoblinkRelay = .init()
    var password = "1234"

    enum CodingKeys: CodingKey {
        case server,
             client,
             password
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.server, streamer)
        try container.encode(.client, relay)
        try container.encode(.password, password)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamer = container.decode(.server, SettingsMoblinkStreamer.self, .init())
        relay = container.decode(.client, SettingsMoblinkRelay.self, .init())
        password = container.decode(.password, String.self, "1234")
    }
}
