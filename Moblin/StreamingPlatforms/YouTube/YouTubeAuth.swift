import AppAuthCore
import Foundation

let youTubeIssuer = URL(string: "https://accounts.google.com")!
let youTubeClientId = "863735387781-fsq255rst10hksrga8hr23dtlmlth7ti.apps.googleusercontent.com"
let youTubeRedirectUri =
    URL(string: "com.googleusercontent.apps.863735387781-fsq255rst10hksrga8hr23dtlmlth7ti:/")!
let youTubeScopes = [
    "https://www.googleapis.com/auth/youtube",
]
private let youTubeAuthServer = "www.youtube.com"

func storeYouTubeAuthStateInKeychain(streamId: UUID, authState: String) {
    createKeychain(streamId: streamId.uuidString).store(value: authState)
}

func loadYouTubeAuthStateFromKeychain(streamId: UUID) -> String? {
    createKeychain(streamId: streamId.uuidString).load()
}

func removeYouTubeAuthStateInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

func removeUnusedYouTubeAuthStatesInKeychain(usedStreamIds: [UUID]) {
    let usedStreamIds = Set(usedStreamIds.map(\.uuidString))
    for streamId in Keychain.loadStreamIds(server: youTubeAuthServer)
        where !usedStreamIds.contains(streamId)
    {
        createKeychain(streamId: streamId).remove()
    }
}

private func createKeychain(streamId: String) -> Keychain {
    Keychain(streamId: streamId, server: youTubeAuthServer, logPrefix: "youtube: auth")
}
