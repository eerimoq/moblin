import Foundation

class WatchSettingsChat: Codable {
    var fontSize: Float = 17.0
    var timestampEnabled: Bool? = true
    var notificationOnMessage: Bool? = false
}

class WatchSettings: Codable {
    var chat: WatchSettingsChat = .init()
}
