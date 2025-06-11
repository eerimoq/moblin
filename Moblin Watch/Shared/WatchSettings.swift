import Foundation

class WatchSettingsChat: Codable, ObservableObject {
    @Published var fontSize: Float = 17.0
    @Published var timestampEnabled: Bool = true
    @Published var notificationOnMessage: Bool = false
    @Published var notificationRate: Int = 30
    @Published var badges: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case fontSize,
             timestampEnabled,
             notificationOnMessage,
             notificationRate,
             badges
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.fontSize, fontSize)
        try container.encode(.timestampEnabled, timestampEnabled)
        try container.encode(.notificationOnMessage, notificationOnMessage)
        try container.encode(.notificationRate, notificationRate)
        try container.encode(.badges, badges)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = container.decode(.fontSize, Float.self, 17.0)
        timestampEnabled = container.decode(.timestampEnabled, Bool.self, true)
        notificationOnMessage = container.decode(.notificationOnMessage, Bool.self, false)
        notificationRate = container.decode(.notificationRate, Int.self, 30)
        badges = container.decode(.badges, Bool.self, true)
    }
}

class WatchSettingsShow: Codable {
    var thermalState: Bool = true
    var audioLevel: Bool = true
    var speed: Bool = true
}

class WatchSettings: Codable {
    var chat: WatchSettingsChat = .init()
    var show: WatchSettingsShow? = .init()
    var viaRemoteControl: Bool? = false
}
