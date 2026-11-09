import Foundation

class MoblinSettingsWebBrowser: Codable {
    var home: String?
}

class MoblinSettingsSrt: Codable {
    var latency: Int32?
    var adaptiveBitrateEnabled: Bool?
    var dnsLookupStrategy: SettingsDnsLookupStrategy?
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
}

class MoblinSettingsButton: Codable {
    var type: SettingsQuickButtonType
    var enabled: Bool?
    var page: Int?

    init(type: SettingsQuickButtonType) {
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

class MoblinSettingsRemoteControlServerRelay: Codable, ObservableObject {
    var enabled: Bool
    var baseUrl: String
    var bridgeId: String
}

class MoblinSettingsRemoteControlAssistant: Codable {
    var enabled: Bool
    var port: UInt16
    var relay: MoblinSettingsRemoteControlServerRelay?
}

class MoblinSettingsRemoteControlStreamer: Codable {
    var enabled: Bool
    var url: String
}

class MoblinSettingsRemoteControl: Codable {
    var assistant: MoblinSettingsRemoteControlAssistant?
    var streamer: MoblinSettingsRemoteControlStreamer?
    var password: String
}

class MoblinSettingsMoblinCloud: Codable {
    var enabled: Bool
    var key: String
    var url: String?
}

private struct MoblinSettingsUrlError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
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
        let query = try JSONDecoder().decode(
            MoblinSettingsUrl.self,
            from: query.data(using: .utf8)!
        )
        for stream in query.streams ?? [] {
            stream.url = cleanUrl(url: stream.url.trim())
            if let message = isValidUrl(url: stream.url) {
                throw MoblinSettingsUrlError(message: message)
            }
            if let video = stream.video {
                if let fps = video.fps, !SettingsStream.isValidFps(fps: fps) {
                    throw MoblinSettingsUrlError(message: "Unsupported video FPS")
                }
                if let bitrate = video.bitrate, !SettingsStream.isValidBitrate(bitrate: bitrate) {
                    throw MoblinSettingsUrlError(message: "Video bitrate out of range")
                }
                if let maxKeyFrameInterval = video.maxKeyFrameInterval,
                   !SettingsStream.isValidMaxKeyFrameInterval(interval: maxKeyFrameInterval)
                {
                    throw MoblinSettingsUrlError(message: "Max key frame interval out of range")
                }
            }
            if let bitrate = stream.audio?.bitrate, !SettingsStream.isValidAudioBitrate(bitrate: bitrate) {
                throw MoblinSettingsUrlError(message: "Unsupported audio bitrate")
            }
            if let srt = stream.srt {
                if let latency = srt.latency, !SettingsStreamSrt.isValidLatency(latency: latency) {
                    throw MoblinSettingsUrlError(message: "SRT latency out of range")
                }
            }
            if let obs = stream.obs {
                obs.webSocketUrl = cleanUrl(url: obs.webSocketUrl.trim())
                if let message = isValidWebSocketUrl(url: obs.webSocketUrl) {
                    throw MoblinSettingsUrlError(message: message)
                }
            }
        }
        for button in query.quickButtons?.buttons ?? [] {
            if let page = button.page, !SettingsQuickButton.isValidPage(page: page) {
                throw MoblinSettingsUrlError(message: "Quick button page out of range")
            }
        }
        if let remoteControl = query.remoteControl {
            remoteControl.password = remoteControl.password.trim()
            if let assistant = remoteControl.assistant {
                if !SettingsRemoteControlAssistant.isValidPort(port: assistant.port) {
                    throw MoblinSettingsUrlError(message: "Invalid remote control assistant port")
                }
                if let relay = assistant.relay {
                    relay.baseUrl = relay.baseUrl.trim()
                    if let message = isValidWebSocketUrl(url: relay.baseUrl) {
                        throw MoblinSettingsUrlError(message: message)
                    }
                    relay.bridgeId = relay.bridgeId.trim()
                    if !SettingsRemoteControlServerRelay.isValidBridgeId(bridgeId: relay.bridgeId) {
                        throw MoblinSettingsUrlError(message: "Empty remote control relay bridge id")
                    }
                }
            }
            if let streamer = remoteControl.streamer {
                streamer.url = streamer.url.trim()
                if let message = isValidWebSocketUrl(url: streamer.url) {
                    throw MoblinSettingsUrlError(message: message)
                }
            }
        }
        if let url = query.moblinCloud?.url, let message = isValidHttpUrl(url: url.trim()) {
            throw MoblinSettingsUrlError(message: message)
        }
        return query
    }
}
