import Foundation

class WatchSettingsChat: Codable {
    var fontSize: Float = 17.0
    var timestampEnabled: Bool? = true
}

class WatchSettings: Codable {
    var chat: WatchSettingsChat = .init()
}
