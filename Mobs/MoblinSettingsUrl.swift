import Foundation

class MoblinSettingsUrlStreamVideo: Codable {
    var codec: SettingsStreamCodec?
}

class MoblinSettingsUrlStream: Codable {
    var name: String
    var url: String
    var video: MoblinSettingsUrlStreamVideo?
}

class MoblinSettingsUrl: Codable {
    var streams: [MoblinSettingsUrlStream]?

    static func fromString(query: String) throws -> MoblinSettingsUrl {
        let query = try JSONDecoder().decode(
            MoblinSettingsUrl.self,
            from: query.data(using: .utf8)!
        )
        for stream in query.streams ?? [] {
            if let message = isValidUrl(url: stream.url) {
                throw message
            }
        }
        return query
    }
}
