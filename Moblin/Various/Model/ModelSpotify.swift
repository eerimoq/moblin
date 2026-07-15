import Foundation

extension Model {
    func reloadSpotify() {
        stopSpotify()
        startSpotify()
    }

    func startSpotify() {
        guard database.spotify.enabled else {
            return
        }
        spotify.start()
    }

    func stopSpotify() {
        spotify.stop()
    }

    func handleSpotifyAuthenticationUrl(url: URL) {
        spotify.handleAuthenticationUrl(url: url)
    }
}
