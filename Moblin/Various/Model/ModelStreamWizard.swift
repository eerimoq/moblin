import Foundation

enum WizardPlatform {
    case twitch
    case kick
    case youTube
    case afreecaTv
    case custom
    case obs
}

enum WizardNetworkSetup {
    case none
    case obs
    case belaboxCloudObs
    case direct
    case myServers
}

enum WizardCustomProtocol {
    case none
    case srt
    case rtmp
    case rist

    func toDefaultCodec() -> SettingsStreamCodec {
        switch self {
        case .none:
            return .h264avc
        case .srt:
            return .h265hevc
        case .rtmp:
            return .h264avc
        case .rist:
            return .h265hevc
        }
    }
}

extension Model {
    private func cleanWizardUrl(url: String) -> String {
        var cleanedUrl = cleanUrl(url: url)
        if isValidUrl(url: cleanedUrl) != nil {
            cleanedUrl = defaultStreamUrl
            makeErrorToast(
                title: String(localized: "Malformed stream URL"),
                subTitle: String(localized: "Using default")
            )
        }
        return cleanedUrl
    }

    private func createStreamFromWizardCustomUrl() -> String? {
        switch wizardCustomProtocol {
        case .none:
            break
        case .srt:
            if var urlComponents = URLComponents(string: wizardCustomSrtUrl.trim()) {
                urlComponents.queryItems = [
                    URLQueryItem(name: "streamid", value: wizardCustomSrtStreamId.trim()),
                ]
                if let fullUrl = urlComponents.url {
                    return fullUrl.absoluteString
                }
            }
        case .rtmp:
            let rtmpUrl = wizardCustomRtmpUrl
                .trim()
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "\(rtmpUrl)/\(wizardCustomRtmpStreamKey.trim())"
        case .rist:
            return wizardCustomRistUrl.trim()
        }
        return nil
    }

    private func createStreamFromWizardUrl() -> String {
        var url = defaultStreamUrl
        if wizardPlatform == .custom {
            if let customUrl = createStreamFromWizardCustomUrl() {
                url = customUrl
            }
        } else {
            switch wizardNetworkSetup {
            case .none:
                break
            case .obs:
                url = "srt://\(wizardObsAddress):\(wizardObsPort)"
            case .belaboxCloudObs:
                url = wizardBelaboxUrl
            case .direct:
                let ingestUrl = wizardDirectIngest.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                url = "\(ingestUrl)/\(wizardDirectStreamKey)"
            case .myServers:
                if let customUrl = createStreamFromWizardCustomUrl() {
                    url = customUrl
                }
            }
        }
        return cleanWizardUrl(url: url)
    }

    func createStreamFromWizard() {
        let stream = SettingsStream(name: wizardName.trim())
        if wizardPlatform != .custom {
            if wizardNetworkSetup != .direct {
                if wizardObsRemoteControlEnabled {
                    let url = cleanUrl(url: wizardObsRemoteControlUrl.trim())
                    if isValidWebSocketUrl(url: url) == nil {
                        stream.obsWebSocketEnabled = true
                        stream.obsWebSocketUrl = url
                        stream.obsWebSocketPassword = wizardObsRemoteControlPassword.trim()
                        stream.obsSourceName = wizardObsRemoteControlSourceName.trim()
                        stream.obsBrbScene = wizardObsRemoteControlBrbScene.trim()
                    }
                }
            }
        }
        switch wizardPlatform {
        case .twitch:
            stream.twitchChannelName = wizardTwitchChannelName.trim()
            stream.twitchChannelId = wizardTwitchChannelId.trim()
            stream.twitchAccessToken = wizardTwitchAccessToken
            stream.twitchLoggedIn = wizardTwitchLoggedIn
        case .kick:
            stream.kickChannelName = wizardKickChannelName.trim()
        case .youTube:
            if !wizardYouTubeVideoId.isEmpty {
                stream.youTubeVideoId = wizardYouTubeVideoId.trim()
            }
        case .afreecaTv:
            if !wizardAfreecaTvChannelName.isEmpty, !wizardAfreecsTvCStreamId.isEmpty {
                stream.afreecaTvChannelName = wizardAfreecaTvChannelName.trim()
                stream.afreecaTvStreamId = wizardAfreecsTvCStreamId.trim()
            }
        case .obs:
            break
        case .custom:
            break
        }
        stream.chat.bttvEmotes = wizardChatBttv
        stream.chat.ffzEmotes = wizardChatFfz
        stream.chat.seventvEmotes = wizardChatSeventv
        stream.url = createStreamFromWizardUrl()
        switch wizardNetworkSetup {
        case .none:
            stream.codec = wizardCustomProtocol.toDefaultCodec()
        case .obs:
            stream.codec = .h265hevc
        case .belaboxCloudObs:
            stream.codec = .h265hevc
        case .direct:
            stream.codec = .h264avc
        case .myServers:
            stream.codec = wizardCustomProtocol.toDefaultCodec()
        }
        stream.audioBitrate = 128_000
        database.streams.append(stream)
        setCurrentStream(stream: stream)
        reloadStream()
        sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    func resetWizard() {
        wizardPlatform = .custom
        wizardNetworkSetup = .none
        wizardName = ""
        wizardTwitchChannelName = ""
        wizardTwitchChannelId = ""
        wizardTwitchAccessToken = ""
        wizardKickChannelName = ""
        wizardYouTubeVideoId = ""
        wizardAfreecaTvChannelName = ""
        wizardAfreecsTvCStreamId = ""
        wizardObsAddress = ""
        wizardObsPort = ""
        wizardObsRemoteControlEnabled = false
        wizardObsRemoteControlUrl = ""
        wizardObsRemoteControlPassword = ""
        wizardDirectIngest = ""
        wizardDirectStreamKey = ""
        wizardChatBttv = false
        wizardChatFfz = false
        wizardChatSeventv = false
        wizardBelaboxUrl = ""
    }

    func handleSettingsUrlsInWizard(settings: MoblinSettingsUrl) {
        switch wizardNetworkSetup {
        case .none:
            break
        case .obs:
            break
        case .belaboxCloudObs:
            for stream in settings.streams ?? [] {
                wizardName = stream.name
                wizardBelaboxUrl = stream.url
            }
        case .direct:
            break
        case .myServers:
            break
        }
    }
}
