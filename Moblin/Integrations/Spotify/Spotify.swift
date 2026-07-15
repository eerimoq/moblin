import Foundation
import SpotifyiOS

private struct SearchTracksResponse: Codable {
    let tracks: SearchTracksResult
}

private struct SearchTracksResult: Codable {
    let items: [SpotifyTrack]
}

private struct SpotifyTrack: Codable {
    let uri: String
    let name: String
    let artists: [SpotifyArtist]
}

private struct SpotifyArtist: Codable {
    let name: String
}

@MainActor
class Spotify: NSObject {
    private var appRemote: SPTAppRemote?
    private var accessToken: String?
    var isConnected: Bool {
        appRemote?.isConnected ?? false
    }

    private let clientID: String
    private let redirectURL: URL

    init?(clientID: String, redirectURLString: String) {
        guard !clientID.isEmpty,
              !redirectURLString.isEmpty,
              let redirectURL = URL(string: redirectURLString)
        else {
            return nil
        }
        self.clientID = clientID
        self.redirectURL = redirectURL
        super.init()
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .none)
        appRemote?.delegate = self
    }

    func authorize() {
        appRemote?.authorizeAndPlayURI("")
    }

    func handleOpenURL(_ url: URL) -> Bool {
        guard let appRemote else {
            return false
        }
        let parameters = appRemote.authorizationParameters(from: url)
        if let token = parameters?[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote.connectionParameters.accessToken = token
            connect()
            return true
        }
        return false
    }

    func connect() {
        guard let accessToken, !accessToken.isEmpty else {
            return
        }
        appRemote?.connectionParameters.accessToken = accessToken
        appRemote?.connect()
    }

    func disconnect() {
        appRemote?.disconnect()
        accessToken = nil
    }

    func addToQueue(_ query: String, onComplete: @escaping (String?) -> Void) {
        guard let accessToken else {
            onComplete(nil)
            return
        }
        searchTrack(query, accessToken: accessToken) { track in
            guard let track else {
                onComplete(nil)
                return
            }
            self.enqueueTrack(uri: track.uri) { success in
                if success {
                    let artists = track.artists.map(\.name).joined(separator: ", ")
                    onComplete("\(track.name) by \(artists)")
                } else {
                    onComplete(nil)
                }
            }
        }
    }

    private func searchTrack(
        _ query: String,
        accessToken: String,
        onComplete: @escaping (SpotifyTrack?) -> Void
    ) {
        guard var components = URLComponents(string: "https://api.spotify.com/v1/search") else {
            onComplete(nil)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else {
            onComplete(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setAuthorization(bearerAuthorization(accessToken))
                return
            }
            let result = try? JSONDecoder().decode(SearchTracksResponse.self, from: data)
            onComplete(result?.tracks.items.first)
        }
    }

    private func enqueueTrack(uri: String, onComplete: @escaping (Bool) -> Void) {
        guard let appRemote, appRemote.isConnected else {
            enqueueTrackViaWebApi(uri: uri, onComplete: onComplete)
            return
        }
        appRemote.playerAPI?.enqueueTrackUri(uri) { _, error in
            if error != nil {
                self.enqueueTrackViaWebApi(uri: uri, onComplete: onComplete)
            } else {
                onComplete(true)
            }
        }
    }

    private func enqueueTrackViaWebApi(uri: String, onComplete: @escaping (Bool) -> Void) {
        guard let accessToken else {
            onComplete(false)
            return
        }
        guard var components = URLComponents(
            string: "https://api.spotify.com/v1/me/player/queue"
        ) else {
            onComplete(false)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "uri", value: uri),
        ]
        guard let url = components.url else {
            onComplete(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setAuthorization("******")
        httpRequest(request: request) { _, response, error in
            onComplete(error == nil && response?.http?.isSuccessful == true)
        }
    }
}

extension Spotify: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_: SPTAppRemote) {}

    nonisolated func appRemote(_: SPTAppRemote, didFailConnectionAttemptWithError _: any Error) {}

    nonisolated func appRemote(_: SPTAppRemote, didDisconnectWithError _: any Error?) {}
}
