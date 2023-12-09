import Foundation

class MoblinSettingsUrlStreamVideo: Codable {
    var codec: SettingsStreamCodec?
}

class MoblinSettingsUrlStreamObs: Codable {
    var webSocketUrl: String
    var webSocketPassword: String
}

class MoblinSettingsUrlStream: Codable {
    var name: String
    var url: String
    var video: MoblinSettingsUrlStreamVideo?
    var obs: MoblinSettingsUrlStreamObs?
}

class MoblinSettingsUrl: Codable {
    var streams: [MoblinSettingsUrlStream]?

    static func fromString(query: String) throws -> MoblinSettingsUrl {
        let query = try JSONDecoder().decode(
            MoblinSettingsUrl.self,
            from: query.data(using: .utf8)!
        )
        for stream in query.streams ?? [] {
            if let message = isValidUrl(url: cleanUrl(url: stream.url)) {
                throw message
            }
        }
        return query
    }
}
