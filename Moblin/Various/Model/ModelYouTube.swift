import AppAuth
import AppAuthCore
import Foundation

class YouTube {
    // periphery: ignore
    var session: OIDExternalUserAgentSession?
}

extension Model {
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
            guard let userAgent = OIDExternalUserAgentIOS(presenting: rootViewController) else {
                return
            }
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
        guard database.chat.enabled, !stream.youTubeHandle.isEmpty, let youTubeFetchVideoIdStartTime else {
            return
        }
        guard youTubeFetchVideoIdStartTime.duration(to: .now) < .seconds(120) else {
            stopFetchingYouTubeChatVideoId()
            makeErrorToast(title: String(localized: "Failed to fetch YouTube Video ID"),
                           subTitle: String(localized: "You must be live on YouTube for this to work."))
            return
        }
        Task { @MainActor in
            if let videoId = try? await fetchYouTubeVideoId(handle: stream.youTubeHandle) {
                stopFetchingYouTubeChatVideoId()
                guard videoId != stream.youTubeVideoId else {
                    return
                }
                stream.youTubeVideoId = videoId
                if stream.enabled {
                    youTubeVideoIdUpdated()
                }
            }
        }
    }

    func isYouTubeViewersConfigured() -> Bool {
        return stream.youTubeAuthState != nil && !stream.youTubeVideoId.isEmpty
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
            youTubeApi?.listVideos(videoId: self.stream.youTubeVideoId) {
                switch $0 {
                case let .success(response):
                    if let item = response.items.first,
                       let viewers = Int(item.liveStreamingDetails.concurrentViewers)
                    {
                        self.youTubePlatformStatus = .live(viewerCount: viewers)
                    } else {
                        self.youTubePlatformStatus = .offline
                    }
                default:
                    self.youTubePlatformStatus = .unknown
                }
            }
        }
    }
}
