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

class WatchSettingsShow: Codable, ObservableObject {
    @Published var thermalState: Bool = true
    @Published var audioLevel: Bool = true
    @Published var speed: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case thermalState,
             audioLevel,
             speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.thermalState, thermalState)
        try container.encode(.audioLevel, audioLevel)
        try container.encode(.speed, speed)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thermalState = container.decode(.thermalState, Bool.self, true)
        audioLevel = container.decode(.audioLevel, Bool.self, true)
        speed = container.decode(.speed, Bool.self, true)
    }
}

class WatchSettings: Codable, ObservableObject {
    var chat: WatchSettingsChat = .init()
    var show: WatchSettingsShow = .init()
    @Published var viaRemoteControl: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case chat,
             show,
             viaRemoteControl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.chat, chat)
        try container.encode(.show, show)
        try container.encode(.viaRemoteControl, viaRemoteControl)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chat = container.decode(.chat, WatchSettingsChat.self, .init())
        show = container.decode(.show, WatchSettingsShow.self, .init())
        viaRemoteControl = container.decode(.viaRemoteControl, Bool.self, false)
    }
}
