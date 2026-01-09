import Foundation

enum WizardPlatform {
    case twitch
    case kick
    case youTube
    case soop
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
        switch createStreamWizard.customProtocol {
        case .none:
            break
        case .srt:
            if var urlComponents = URLComponents(string: createStreamWizard.customSrtUrl.trim()) {
                urlComponents.queryItems = [
                    URLQueryItem(name: "streamid", value: createStreamWizard.customSrtStreamId.trim()),
                ]
                if let fullUrl = urlComponents.url {
                    return fullUrl.absoluteString
                }
            }
        case .rtmp:
            guard var url = URLComponents(string: createStreamWizard.customRtmpUrl
                .trim()
                .trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            else {
                return nil
            }
            url.path += "/\(createStreamWizard.customRtmpStreamKey.trim())"
            return url.url?.absoluteString
        case .rist:
            return createStreamWizard.customRistUrl.trim()
        }
        return nil
    }

    private func createStreamFromWizardUrl() -> String {
        var url = defaultStreamUrl
        if createStreamWizard.platform == .custom {
            if let customUrl = createStreamFromWizardCustomUrl() {
                url = customUrl
            }
        } else {
            switch createStreamWizard.networkSetup {
            case .none:
                break
            case .obs:
                url = "srt://\(createStreamWizard.obsAddress):\(createStreamWizard.obsPort)"
            case .belaboxCloudObs:
                url = createStreamWizard.belaboxUrl
            case .direct:
                let ingestUrl = createStreamWizard.directIngest
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                url = "\(ingestUrl)/\(createStreamWizard.directStreamKey)"
            case .myServers:
                if let customUrl = createStreamFromWizardCustomUrl() {
                    url = customUrl
                }
            }
        }
        return cleanWizardUrl(url: url)
    }

    func createStreamFromWizard() {
        let stream = SettingsStream(name: createStreamWizard.name.trim())
        stream.backgroundStreaming = createStreamWizard.backgroundStreaming
        if createStreamWizard.platform != .custom {
            if createStreamWizard.networkSetup != .direct {
                if createStreamWizard.obsRemoteControlEnabled {
                    let url = cleanUrl(url: createStreamWizard.obsRemoteControlUrl.trim())
                    if isValidWebSocketUrl(url: url) == nil {
                        stream.obsWebSocketEnabled = true
                        stream.obsWebSocketUrl = url
                        stream.obsWebSocketPassword = createStreamWizard.obsRemoteControlPassword.trim()
                        stream.obsSourceName = createStreamWizard.obsRemoteControlSourceName.trim()
                        stream.obsMainScene = createStreamWizard.obsRemoteControlMainScene.trim()
                        stream.obsBrbScene = createStreamWizard.obsRemoteControlBrbScene.trim()
                        stream.streamingDirectlyToObs = createStreamWizard.networkSetup == .obs
                    }
                }
            }
        }
        switch createStreamWizard.platform {
        case .twitch:
            stream.twitchChannelName = createStreamWizard.twitchChannelName.trim()
            stream.twitchChannelId = createStreamWizard.twitchChannelId.trim()
            stream.twitchAccessToken = createStreamWizard.twitchAccessToken
            stream.twitchLoggedIn = createStreamWizard.twitchLoggedIn
            if stream.twitchLoggedIn, !stream.twitchAccessToken.isEmpty {
                storeTwitchAccessTokenInKeychain(streamId: stream.id, accessToken: stream.twitchAccessToken)
            }
        case .kick:
            stream.kickChannelName = createStreamWizard.kickChannelName.trim()
            stream.kickAccessToken = createStreamWizard.kickAccessToken
            stream.kickLoggedIn = createStreamWizard.kickLoggedIn
            stream.kickChannelId = createStreamWizard.kickChannelId
            stream.kickSlug = createStreamWizard.kickSlug
            stream.kickChatroomChannelId = createStreamWizard.kickChatroomChannelId
        case .youTube:
            stream.youTubeHandle = createStreamWizard.youTubeHandle.trim()
        case .soop:
            if !createStreamWizard.soopChannelName.isEmpty, !createStreamWizard.soopStreamId.isEmpty {
                stream.soopChannelName = createStreamWizard.soopChannelName.trim()
                stream.soopStreamId = createStreamWizard.soopStreamId.trim()
            }
        case .obs:
            break
        case .custom:
            break
        }
        stream.chat.bttvEmotes = false
        stream.chat.ffzEmotes = false
        stream.chat.seventvEmotes = false
        stream.url = createStreamFromWizardUrl()
        switch createStreamWizard.networkSetup {
        case .none:
            stream.codec = createStreamWizard.customProtocol.toDefaultCodec()
        case .obs:
            stream.codec = .h265hevc
        case .belaboxCloudObs:
            stream.codec = .h265hevc
        case .direct:
            stream.codec = .h264avc
        case .myServers:
            stream.codec = createStreamWizard.customProtocol.toDefaultCodec()
        }
        stream.audioBitrate = 128_000
        database.streams.append(stream)
        setCurrentStream(stream: stream)
        reloadStream()
        sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    func resetWizard() {
        createStreamWizard.platform = .custom
        createStreamWizard.networkSetup = .none
        createStreamWizard.name = ""
        createStreamWizard.backgroundStreaming = false
        createStreamWizard.twitchChannelName = ""
        createStreamWizard.twitchChannelId = ""
        createStreamWizard.twitchAccessToken = ""
        createStreamWizard.twitchLoggedIn = false
        createStreamWizard.kickChannelName = ""
        createStreamWizard.kickAccessToken = ""
        createStreamWizard.kickLoggedIn = false
        createStreamWizard.kickChannelId = nil
        createStreamWizard.kickSlug = nil
        createStreamWizard.kickChatroomChannelId = nil
        createStreamWizard.youTubeHandle = ""
        createStreamWizard.soopChannelName = ""
        createStreamWizard.soopStreamId = ""
        createStreamWizard.obsAddress = ""
        createStreamWizard.obsPort = ""
        createStreamWizard.obsRemoteControlEnabled = false
        createStreamWizard.obsRemoteControlUrl = ""
        createStreamWizard.obsRemoteControlPassword = ""
        createStreamWizard.directIngest = ""
        createStreamWizard.directStreamKey = ""
        createStreamWizard.belaboxUrl = ""
    }

    func handleSettingsUrlsInWizard(settings: MoblinSettingsUrl) {
        switch createStreamWizard.networkSetup {
        case .none:
            break
        case .obs:
            break
        case .belaboxCloudObs:
            for stream in settings.streams ?? [] {
                createStreamWizard.name = stream.name
                createStreamWizard.belaboxUrl = stream.url
            }
        case .direct:
            break
        case .myServers:
            break
        }
    }
}
