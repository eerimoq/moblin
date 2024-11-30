import Foundation

class WatchSettingsChat: Codable {
    var fontSize: Float = 17.0
    var timestampEnabled: Bool? = true
    var notificationOnMessage: Bool? = false
    var badges: Bool? = true
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
