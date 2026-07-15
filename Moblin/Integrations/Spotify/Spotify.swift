import Foundation

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
class Spotify {
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    private func authorization() -> String {
        "Bearer \(accessToken)"
    }

    func addToQueue(_ query: String, onComplete: @escaping (String?) -> Void) {
        searchTrack(query) { track in
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

    private func searchTrack(_ query: String, onComplete: @escaping (SpotifyTrack?) -> Void) {
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
        request.setAuthorization(authorization())
        httpRequest(request: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil)
                return
            }
            let result = try? JSONDecoder().decode(SearchTracksResponse.self, from: data)
            onComplete(result?.tracks.items.first)
        }
    }

    private func enqueueTrack(uri: String, onComplete: @escaping (Bool) -> Void) {
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
        request.setAuthorization(authorization())
        request.setContentType("application/json")
        httpRequest(request: request) { _, response, error in
            onComplete(error == nil && response?.http?.isSuccessful == true)
        }
    }
}
