import AppAuth
import AppAuthCore
import Foundation

class YouTube {
    // periphery: ignore
    var session: (any OIDExternalUserAgentSession)?
}

extension Model {
    func youTubeVideoIdUpdated() {
        reloadViewers()
        reloadYouTubeLiveChat()
        resetChat()
    }

    func updateViewersYouTube() -> StreamingPlatformStatus {
        StreamingPlatformStatus(platform: .youTube, status: youTubePlatformStatus)
    }

    func youTubeSignIn(stream: SettingsStream) {
        guard let rootViewController = getRootViewController() else {
            return
        }
        OIDAuthorizationService.discoverConfiguration(forIssuer: youTubeIssuer) { configuration, _ in
            guard let configuration else {
                return
            }
            let request = OIDAuthorizationRequest(configuration: configuration,
                                                  clientId: youTubeClientId,
                                                  clientSecret: nil,
                                                  scopes: youTubeScopes,
                                                  redirectURL: youTubeRedirectUri,
                                                  responseType: OIDResponseTypeCode,
                                                  additionalParameters: nil)
            #if targetEnvironment(macCatalyst)
            guard let userAgent = OIDExternalUserAgentCatalyst(presenting: rootViewController) else {
                return
            }
            #else
            guard let userAgent = OIDExternalUserAgentIOS(presenting: rootViewController) else {
                return
            }
            #endif
            self.youTube.session = OIDAuthState.authState(
                byPresenting: request,
                externalUserAgent: userAgent
            ) { authState, _ in
                stream.youTubeAuthState = authState
                self.youTube.session = nil
            }
        }
    }

    func youTubeSignOut(stream: SettingsStream) {
        stream.youTubeAuthState = nil
        removeYouTubeAuthStateInKeychain(streamId: stream.id)
    }

    func getYouTubeApi(stream: SettingsStream, onCompleted: @escaping (YouTubeApi?) -> Void) {
        getYouTubeAccesssToken(stream: stream) {
            guard let accessToken = $0 else {
                onCompleted(nil)
                return
            }
            onCompleted(YouTubeApi(accessToken: accessToken))
        }
    }

    func startFetchingYouTubeChatVideoId() {
        youTubeFetchVideoIdStartTime = .now
    }

    func stopFetchingYouTubeChatVideoId() {
        youTubeFetchVideoIdStartTime = nil
    }

    func tryToFetchYouTubeVideoId() {
        guard database.chat.enabled, let youTubeFetchVideoIdStartTime else {
            return
        }
        guard youTubeFetchVideoIdStartTime.duration(to: .now) < .seconds(120) else {
            stopFetchingYouTubeChatVideoId()
            makeErrorToast(title: String(localized: "Failed to fetch YouTube Video ID"),
                           subTitle: String(localized: "You must be live on YouTube for this to work."))
            return
        }
        if stream.youTubeAuthState != nil {
            getYouTubeApi(stream: stream) { youTubeApi in
                guard let youTubeApi else { return }
                youTubeApi.listLiveBroadcasts(status: "active") { response in
                    Task { @MainActor in
                        switch response {
                        case let .success(listResponse):
                            let videoIds = listResponse.items.map(\.id)
                            guard !videoIds.isEmpty else { return }
                            self.stopFetchingYouTubeChatVideoId()
                            let newVideoIdString = videoIds.joined(separator: ",")
                            guard newVideoIdString != self.stream.youTubeVideoIds else { return }
                            self.stream.youTubeVideoIds = newVideoIdString
                            if self.stream.enabled { self.youTubeVideoIdUpdated() }
                        default:
                            break
                        }
                    }
                }
            }
        } else if !stream.youTubeHandle.isEmpty {
            Task { @MainActor in
                if let videoId = try? await fetchYouTubeVideoId(handle: stream.youTubeHandle) {
                    stopFetchingYouTubeChatVideoId()
                    guard videoId != stream.youTubeVideoIds else { return }
                    stream.youTubeVideoIds = videoId
                    if stream.enabled { youTubeVideoIdUpdated() }
                }
            }
        }
    }

    func isYouTubeViewersConfigured() -> Bool {
        stream.youTubeAuthState != nil && !stream.youTubeVideoIds.isEmpty
    }

    func isYouTubeLiveChatConfigured() -> Bool {
        database.chat.enabled && stream.youTubeVideoIds != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        youTubeLiveChats.values.contains(where: { $0.isConnected() })
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        youTubeLiveChats.values.contains(where: { $0.hasEmotes() })
    }

    func reloadYouTubeLiveChat() {
        for chat in youTubeLiveChats.values {
            chat.stop()
        }
        youTubeLiveChats.removeAll()
        if isYouTubeLiveChatConfigured(), !isRemoteControlChatAndEvents(platform: .youTube) {
            let videoIds = stream.youTubeVideoIds
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for videoId in videoIds {
                let chat = YouTubeLiveChat(model: self, videoId: videoId, settings: stream.chat)
                youTubeLiveChats[videoId] = chat
                chat.start()
            }
        }
        updateChatMoreThanOneChatConfigured()
    }

    func updateYouTubeStream(monotonicNow: ContinuousClock.Instant) {
        guard isLive, isYouTubeViewersConfigured() else {
            youTubePlatformStatus = .unknown
            return
        }
        guard youTubeStreamUpdateTime.duration(to: monotonicNow) > youTubeStreamUpdateTimePollDelta else {
            return
        }
        youTubeStreamUpdateTime = monotonicNow
        youTubeStreamUpdateTimePollDelta = min(youTubeStreamUpdateTimePollDelta * 2, .seconds(900))
        getVideo()
    }

    private func getYouTubeAccesssToken(stream: SettingsStream, onCompleted: @escaping (String?) -> Void) {
        guard let authState = stream.youTubeAuthState else {
            onCompleted(nil)
            return
        }
        authState.performAction { accessToken, _, error in
            guard let accessToken, error == nil else {
                onCompleted(nil)
                return
            }
            onCompleted(accessToken)
        }
    }

    private func getVideo() {
        getYouTubeApi(stream: stream) { youTubeApi in
            youTubeApi?.listVideos(videoId: self.stream.youTubeVideoIds) { response in
                Task { @MainActor in
                    switch response {
                    case let .success(response):
                        var totalViewers = 0
                        var isLive = false
                        for item in response.items {
                            let liveStreamingDetails = item.liveStreamingDetails
                            if liveStreamingDetails.isLive() {
                                isLive = true
                                totalViewers += Int(liveStreamingDetails.concurrentViewers ?? "0") ?? 0
                            }
                        }
                        if isLive {
                            self.youTubePlatformStatus = .live(viewerCount: totalViewers)
                        } else if !response.items.isEmpty {
                            self.youTubePlatformStatus = .offline
                        } else {
                            self.youTubePlatformStatus = .unknown
                        }
                    default:
                        self.youTubePlatformStatus = .unknown
                    }
                }
            }
        }
    }
}
