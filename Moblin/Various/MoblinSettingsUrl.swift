import Foundation

class MoblinSettingsWebBrowser: Codable {
    var home: String?
}

class MoblinSettingsSrt: Codable {
    var latency: Int32?
    var adaptiveBitrateEnabled: Bool?
}

class MoblinSettingsUrlStreamVideo: Codable {
    var resolution: SettingsStreamResolution?
    var fps: Int?
    var bitrate: UInt32?
    var codec: SettingsStreamCodec?
    var bFrames: Bool?
    var maxKeyFrameInterval: Int32?
}

class MoblinSettingsUrlStreamAudio: Codable {
    var bitrate: Int?
}

class MoblinSettingsUrlStreamObs: Codable {
    var webSocketUrl: String
    var webSocketPassword: String

    init(webSocketUrl: String, webSocketPassword: String) {
        self.webSocketUrl = webSocketUrl
        self.webSocketPassword = webSocketPassword
    }
}

class MoblinSettingsUrlStreamTwitch: Codable {
    var channelName: String
    var channelId: String

    init(channelName: String, channelId: String) {
        self.channelName = channelName
        self.channelId = channelId
    }
}

class MoblinSettingsUrlStreamKick: Codable {
    var channelName: String

    init(channelName: String) {
        self.channelName = channelName
    }
}

class MoblinSettingsUrlStream: Codable {
    var name: String
    var url: String
    // periphery:ignore
    var enabled: Bool?
    var selected: Bool?
    var video: MoblinSettingsUrlStreamVideo?
    var audio: MoblinSettingsUrlStreamAudio?
    var srt: MoblinSettingsSrt?
    var obs: MoblinSettingsUrlStreamObs?
    var twitch: MoblinSettingsUrlStreamTwitch?
    var kick: MoblinSettingsUrlStreamKick?

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

class MoblinSettingsButton: Codable {
    var type: SettingsButtonType
    var enabled: Bool?

    init(type: SettingsButtonType) {
        self.type = type
    }
}

class MoblinQuickButtons: Codable {
    var twoColumns: Bool?
    var showName: Bool?
    var enableScroll: Bool?
    // Use "buttons" to enable buttons after disabling all.
    var disableAllButtons: Bool?
    var buttons: [MoblinSettingsButton]?
}

class MoblinSettingsUrl: Codable {
    // The last enabled stream will be selected (if any).
    var streams: [MoblinSettingsUrlStream]?
    var quickButtons: MoblinQuickButtons?
    var webBrowser: MoblinSettingsWebBrowser?

    func toString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try String.fromUtf8(data: encoder.encode(self))
    }

    static func fromString(query: String) throws -> MoblinSettingsUrl {
        let query = try JSONDecoder().decode(
            MoblinSettingsUrl.self,
            from: query.data(using: .utf8)!
        )
        for stream in query.streams ?? [] {
            if let message = isValidUrl(url: cleanUrl(url: stream.url)) {
                throw message
            }
            if let srt = stream.srt {
                if let latency = srt.latency {
                    if latency < 0 {
                        throw "Negative SRT latency"
                    }
                }
            }
            if let obs = stream.obs {
                if let message = isValidWebSocketUrl(url: cleanUrl(url: obs.webSocketUrl)) {
                    throw message
                }
            }
        }
        return query
    }
}
