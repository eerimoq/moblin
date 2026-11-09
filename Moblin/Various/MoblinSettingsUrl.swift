import Foundation

private struct MoblinSettingsUrlError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private extension KeyedDecodingContainer {
    func decodeEnumIfPresent<T: RawRepresentable>(_: T.Type,
                                                  forKey key: Key,
                                                  _ message: String) throws -> T?
        where T.RawValue == String
    {
        guard let rawValue = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        guard let value = T(rawValue: rawValue) else {
            throw MoblinSettingsUrlError(message: message)
        }
        return value
    }
}

class MoblinSettingsWebBrowser: Codable {
    var home: String?
}

class MoblinSettingsSrt: Codable {
    var latency: Int32?
    var adaptiveBitrateEnabled: Bool?
    var dnsLookupStrategy: SettingsDnsLookupStrategy?

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latency = try container.decodeIfPresent(Int32.self, forKey: .latency)
        if let latency, !SettingsStreamSrt.isValidLatency(latency: latency) {
            throw MoblinSettingsUrlError(message: "SRT latency out of range")
        }
        adaptiveBitrateEnabled = try container.decodeIfPresent(Bool.self, forKey: .adaptiveBitrateEnabled)
        dnsLookupStrategy = try container.decodeEnumIfPresent(SettingsDnsLookupStrategy.self,
                                                              forKey: .dnsLookupStrategy,
                                                              "Unsupported SRT DNS lookup strategy")
    }
}

class MoblinSettingsUrlStreamVideo: Codable {
    var resolution: SettingsStreamResolution?
    var fps: Int?
    var bitrate: UInt32?
    var codec: SettingsStreamCodec?
    var bFrames: Bool?
    var maxKeyFrameInterval: Int32?

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try container.decodeEnumIfPresent(SettingsStreamResolution.self,
                                                       forKey: .resolution,
                                                       "Unsupported video resolution")
        fps = try container.decodeIfPresent(Int.self, forKey: .fps)
        if let fps, !SettingsStream.isValidFps(fps: fps) {
            throw MoblinSettingsUrlError(message: "Unsupported video FPS")
        }
        bitrate = try container.decodeIfPresent(UInt32.self, forKey: .bitrate)
        if let bitrate, !SettingsStream.isValidBitrate(bitrate: bitrate) {
            throw MoblinSettingsUrlError(message: "Video bitrate out of range")
        }
        codec = try container.decodeEnumIfPresent(SettingsStreamCodec.self,
                                                  forKey: .codec,
                                                  "Unsupported video codec")
        bFrames = try container.decodeIfPresent(Bool.self, forKey: .bFrames)
        maxKeyFrameInterval = try container.decodeIfPresent(Int32.self, forKey: .maxKeyFrameInterval)
        if let maxKeyFrameInterval,
           !SettingsStream.isValidMaxKeyFrameInterval(interval: maxKeyFrameInterval)
        {
            throw MoblinSettingsUrlError(message: "Max key frame interval out of range")
        }
    }
}

class MoblinSettingsUrlStreamAudio: Codable {
    var bitrate: Int?

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate)
        if let bitrate, !SettingsStream.isValidAudioBitrate(bitrate: bitrate) {
            throw MoblinSettingsUrlError(message: "Unsupported audio bitrate")
        }
    }
}

class MoblinSettingsUrlStreamObs: Codable {
    var webSocketUrl: String
    var webSocketPassword: String

    init(webSocketUrl: String, webSocketPassword: String) {
        self.webSocketUrl = webSocketUrl
        self.webSocketPassword = webSocketPassword
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        webSocketUrl = try cleanUrl(url: container.decode(String.self, forKey: .webSocketUrl).trim())
        if let message = isValidWebSocketUrl(url: webSocketUrl) {
            throw MoblinSettingsUrlError(message: message)
        }
        webSocketPassword = try container.decode(String.self, forKey: .webSocketPassword)
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
    var selected: Bool?
    var backgroundStreaming: Bool?
    var backgroundStreamingPiP: Bool?
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

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try cleanUrl(url: container.decode(String.self, forKey: .url).trim())
        if let message = isValidUrl(url: url) {
            throw MoblinSettingsUrlError(message: message)
        }
        selected = try container.decodeIfPresent(Bool.self, forKey: .selected)
        backgroundStreaming = try container.decodeIfPresent(Bool.self, forKey: .backgroundStreaming)
        backgroundStreamingPiP = try container.decodeIfPresent(Bool.self, forKey: .backgroundStreamingPiP)
        video = try container.decodeIfPresent(MoblinSettingsUrlStreamVideo.self, forKey: .video)
        audio = try container.decodeIfPresent(MoblinSettingsUrlStreamAudio.self, forKey: .audio)
        srt = try container.decodeIfPresent(MoblinSettingsSrt.self, forKey: .srt)
        obs = try container.decodeIfPresent(MoblinSettingsUrlStreamObs.self, forKey: .obs)
        twitch = try container.decodeIfPresent(MoblinSettingsUrlStreamTwitch.self, forKey: .twitch)
        kick = try container.decodeIfPresent(MoblinSettingsUrlStreamKick.self, forKey: .kick)
    }
}

class MoblinSettingsButton: Codable {
    var type: SettingsQuickButtonType
    var enabled: Bool?
    var page: Int?

    init(type: SettingsQuickButtonType) {
        self.type = type
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(SettingsQuickButtonType.self, forKey: .type)
        if type == .unknown {
            throw MoblinSettingsUrlError(message: "Unknown quick button type")
        }
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        if let page, !SettingsQuickButton.isValidPage(page: page) {
            throw MoblinSettingsUrlError(message: "Quick button page out of range")
        }
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

class MoblinSettingsRemoteControlServerRelay: Codable, ObservableObject {
    var enabled: Bool
    var baseUrl: String
    var bridgeId: String

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        baseUrl = try container.decode(String.self, forKey: .baseUrl).trim()
        if let message = isValidWebSocketUrl(url: baseUrl) {
            throw MoblinSettingsUrlError(message: message)
        }
        bridgeId = try container.decode(String.self, forKey: .bridgeId).trim()
        if !SettingsRemoteControlServerRelay.isValidBridgeId(bridgeId: bridgeId) {
            throw MoblinSettingsUrlError(message: "Empty remote control relay bridge id")
        }
    }
}

class MoblinSettingsRemoteControlAssistant: Codable {
    var enabled: Bool
    var port: UInt16
    var relay: MoblinSettingsRemoteControlServerRelay?

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        port = try container.decode(UInt16.self, forKey: .port)
        if !SettingsRemoteControlAssistant.isValidPort(port: port) {
            throw MoblinSettingsUrlError(message: "Invalid remote control assistant port")
        }
        relay = try container.decodeIfPresent(MoblinSettingsRemoteControlServerRelay.self, forKey: .relay)
    }
}

class MoblinSettingsRemoteControlStreamer: Codable {
    var enabled: Bool
    var url: String

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        url = try container.decode(String.self, forKey: .url).trim()
        if let message = isValidWebSocketUrl(url: url) {
            throw MoblinSettingsUrlError(message: message)
        }
    }
}

class MoblinSettingsRemoteControl: Codable {
    var assistant: MoblinSettingsRemoteControlAssistant?
    var streamer: MoblinSettingsRemoteControlStreamer?
    var password: String

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistant = try container.decodeIfPresent(
            MoblinSettingsRemoteControlAssistant.self,
            forKey: .assistant
        )
        streamer = try container.decodeIfPresent(MoblinSettingsRemoteControlStreamer.self, forKey: .streamer)
        password = try container.decode(String.self, forKey: .password).trim()
    }
}

class MoblinSettingsMoblinCloud: Codable {
    var enabled: Bool
    var key: String
    var url: String?

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        key = try container.decode(String.self, forKey: .key)
        url = try container.decodeIfPresent(String.self, forKey: .url)?.trim()
        if let url, let message = isValidHttpUrl(url: url) {
            throw MoblinSettingsUrlError(message: message)
        }
    }
}

class MoblinSettingsUrl: Codable {
    // The last enabled stream will be selected (if any).
    var streams: [MoblinSettingsUrlStream]?
    var quickButtons: MoblinQuickButtons?
    var webBrowser: MoblinSettingsWebBrowser?
    var remoteControl: MoblinSettingsRemoteControl?
    var moblinCloud: MoblinSettingsMoblinCloud?

    func toString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try String.fromUtf8(data: encoder.encode(self))
    }

    static func fromString(query: String) throws -> MoblinSettingsUrl {
        try JSONDecoder().decode(MoblinSettingsUrl.self, from: query.data(using: .utf8)!)
    }
}
