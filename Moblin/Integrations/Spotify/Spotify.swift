#if targetEnvironment(macCatalyst)

import Foundation

class Spotify: NSObject {
    func start() {}

    func stop() {}

    func handleAuthenticationUrl(url _: URL) {}

    func enqueue(track _: String) {}

    func play(track _: String?) {}

    func pause() {}

    func next() {}

    func previous() {}
}

#else

import SpotifyiOS

class Spotify: NSObject {
    private let appRemote: SPTAppRemote

    override init() {
        let configuration = SPTConfiguration(
            clientID: "df41b36c765b430e8f6dd30a7f474d6c",
            redirectURL: URL(string: "moblin://spotify")!
        )
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .none)
        super.init()
        appRemote.delegate = self
    }

    func start() {
        if appRemote.connectionParameters.accessToken != nil {
            appRemote.connect()
        } else {
            appRemote.authorizeAndPlayURI("") { spotifyInstalled in
                if !spotifyInstalled {
                    logger.info("spotify: Not installed")
                }
            }
        }
    }

    func stop() {
        appRemote.disconnect()
    }

    func handleAuthenticationUrl(url: URL) {
        let parameters = appRemote.authorizationParameters(from: url)
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            appRemote.connect()
        }
    }

    func play(track: String?) {
        if let track {
            player()?.play(track, asRadio: false) { _, _ in
            }
        } else {
            player()?.resume()
        }
    }

    func pause() {
        player()?.pause()
    }

    func enqueue(track: String) {
        guard let track = makeSpotifyTrack(value: track) else {
            return
        }
        player()?.enqueueTrackUri(track)
    }

    func next() {
        player()?.skip(toNext: nil)
    }

    func previous() {
        player()?.skip(toPrevious: nil)
    }

    private func player() -> SPTAppRemotePlayerAPI? {
        appRemote.playerAPI
    }
}

extension Spotify: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_: SPTAppRemote) {
        logger.info("spotify: connected")
    }

    func appRemote(_: SPTAppRemote, didFailConnectionAttemptWithError error: (any Error)?) {
        logger.info("spotify: didFailConnectionAttemptWithError \(error?.localizedDescription ?? "")")
    }

    func appRemote(_: SPTAppRemote, didDisconnectWithError error: (any Error)?) {
        logger.info("spotify: didDisconnectWithError \(error?.localizedDescription ?? "")")
    }
}

#endif

func makeSpotifyTrack(value: String) -> String? {
    if value.isEmpty {
        nil
    } else if value.starts(with: "spotify:track:") {
        value
    } else if let track = URL(string: value)?.pathComponents.last {
        "spotify:track:\(track)"
    } else {
        "spotify:track:\(value)"
    }
}
