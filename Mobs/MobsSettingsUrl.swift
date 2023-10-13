import Foundation

class MobsSettingsUrlStreamVideo: Codable {
    var codec: SettingsStreamCodec?
}

class MobsSettingsUrlStream: Codable {
    var name: String
    var url: String
    var video: MobsSettingsUrlStreamVideo?
}

class MobsSettingsUrl: Codable {
    var streams: [MobsSettingsUrlStream]?

    static func fromString(query: String) throws -> MobsSettingsUrl {
        let query = try JSONDecoder().decode(
            MobsSettingsUrl.self,
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
