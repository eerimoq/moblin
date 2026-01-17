import AppAuthCore
import Foundation

let youTubeIssuer = URL(string: "https://accounts.google.com")!
let youTubeClientId = "863735387781-fsq255rst10hksrga8hr23dtlmlth7ti.apps.googleusercontent.com"
let youTubeRedirectUri =
    URL(string: "com.googleusercontent.apps.863735387781-fsq255rst10hksrga8hr23dtlmlth7ti:/")!
let youTubeScopes = [
    "https://www.googleapis.com/auth/youtube",
]

func storeYouTubeAuthStateInKeychain(streamId: UUID, authState: String) {
    createKeychain(streamId: streamId.uuidString).store(value: authState)
}

func loadYouTubeAuthStateFromKeychain(streamId: UUID) -> String? {
    return createKeychain(streamId: streamId.uuidString).load()
}

func removeYouTubeAuthStateInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

private func createKeychain(streamId: String) -> Keychain {
    return Keychain(streamId: streamId, server: "www.youtube.com", logPrefix: "youtube: auth")
}
