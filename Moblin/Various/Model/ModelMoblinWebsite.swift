import CryptoKit
import DeviceCheck
import Foundation

private let liveUrl = URL(string: "https://api.moblin.app/streamers/live")!
private let challengeUrl = URL(string: "https://api.moblin.app/streamers/live/challenge")!
private let appAttestStorage = SimpleStringStorage(key: "moblinWebsiteAppAttest")

private struct MoblinWebsiteChannel: Encodable {
    let platform: String
    let name: String
}

private struct MoblinWebsiteLive: Encodable {
    let channels: [MoblinWebsiteChannel]
    let challenge: String
    let keyId: String
    let attestation: String
    let attestationChallenge: String
}

private struct MoblinWebsiteChallenge: Decodable {
    let challenge: String
}

private struct MoblinWebsiteAppAttest: Codable {
    let keyId: String
    let challenge: Data
    var attestation: Data?
}

private enum MoblinWebsiteError: Error {
    case keyRejected(String)
    case badResponse(String)
}

private func describe(_ response: URLResponse, _ data: Data) -> String {
    guard let response = response.http else {
        return "not HTTP"
    }
    return "\(response.statusCode) \(String(bytes: data, encoding: .utf8) ?? "")"
}

private func loadAppAttest() -> MoblinWebsiteAppAttest? {
    try? JSONDecoder().decode(MoblinWebsiteAppAttest.self, from: Data(appAttestStorage.get().utf8))
}

private func storeAppAttest(_ appAttest: MoblinWebsiteAppAttest?) {
    guard let appAttest, let data = try? JSONEncoder().encode(appAttest) else {
        appAttestStorage.set("")
        return
    }
    appAttestStorage.set(String(bytes: data, encoding: .utf8) ?? "")
}

private func attestedKey() async throws -> MoblinWebsiteAppAttest {
    let service = DCAppAttestService.shared
    var appAttest: MoblinWebsiteAppAttest
    if let stored = loadAppAttest() {
        if stored.attestation != nil {
            return stored
        }
        appAttest = stored
    } else {
        let keyId = try await service.generateKey()
        let challenge = Data((0 ..< 32).map { _ in UInt8.random(in: .min ... .max) })
        appAttest = MoblinWebsiteAppAttest(keyId: keyId, challenge: challenge, attestation: nil)
        storeAppAttest(appAttest)
    }
    do {
        let clientDataHash = Data(SHA256.hash(data: appAttest.challenge))
        appAttest.attestation = try await service.attestKey(appAttest.keyId, clientDataHash: clientDataHash)
    } catch let error as DCError where error.code == .serverUnavailable {
        throw error
    } catch {
        storeAppAttest(nil)
        throw error
    }
    storeAppAttest(appAttest)
    return appAttest
}

private func fetchChallenge() async throws -> String {
    var request = URLRequest(url: challengeUrl, timeoutInterval: 30)
    request.httpMethod = "POST"
    let (data, response) = try await URLSession.shared.data(for: request)
    guard response.http?.isSuccessful == true else {
        throw MoblinWebsiteError.badResponse("challenge: \(describe(response, data))")
    }
    return try JSONDecoder().decode(MoblinWebsiteChallenge.self, from: data).challenge
}

private func postLive(channels: [MoblinWebsiteChannel], appAttest: MoblinWebsiteAppAttest) async throws {
    let challenge = try await fetchChallenge()
    let live = MoblinWebsiteLive(
        channels: channels,
        challenge: challenge,
        keyId: appAttest.keyId,
        attestation: appAttest.attestation!.base64EncodedString(),
        attestationChallenge: appAttest.challenge.base64EncodedString()
    )
    let body = try JSONEncoder().encode(live)
    let clientDataHash = Data(SHA256.hash(data: body))
    let assertion: Data
    do {
        assertion = try await DCAppAttestService.shared.generateAssertion(
            appAttest.keyId,
            clientDataHash: clientDataHash
        )
    } catch {
        throw MoblinWebsiteError.keyRejected("assertion: \(error)")
    }
    var request = URLRequest(url: liveUrl, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "Moblin-Assertion")
    request.httpBody = body
    let (data, response) = try await URLSession.shared.data(for: request)
    if response.http?.isUnauthorized == true {
        throw MoblinWebsiteError.keyRejected("live: \(describe(response, data))")
    }
    guard response.http?.isSuccessful == true else {
        throw MoblinWebsiteError.badResponse("live: \(describe(response, data))")
    }
}

private func sendLive(channels: [MoblinWebsiteChannel]) async {
    guard DCAppAttestService.shared.isSupported else {
        logger.info("moblin-website: App Attest is not supported on this device")
        return
    }
    do {
        let attestedBefore = loadAppAttest()?.attestation != nil
        do {
            try await postLive(channels: channels, appAttest: attestedKey())
        } catch let MoblinWebsiteError.keyRejected(reason) where attestedBefore {
            logger.info("moblin-website: Key rejected (\(reason)), attesting a new one")
            storeAppAttest(nil)
            try await postLive(channels: channels, appAttest: attestedKey())
        }
    } catch {
        logger.info("moblin-website: Failed to send live: \(error)")
    }
}

extension Model {
    func sendLiveToMoblinWebsite() {
        guard !isMac(), stream.goLiveNotificationMoblinWebsite else {
            return
        }
        var channels: [MoblinWebsiteChannel] = []
        let twitchChannelName = stream.twitchChannelName.trim()
        if stream.twitchLoggedIn, !twitchChannelName.isEmpty {
            channels.append(.init(platform: "twitch", name: twitchChannelName))
        }
        let youTubeHandle = String(stream.youTubeHandle.trim().trimmingPrefix("@"))
        if stream.isYouTubeAuthorized(), !youTubeHandle.isEmpty {
            channels.append(.init(platform: "youtube", name: youTubeHandle))
        }
        let kickChannelName = stream.kickChannelName.trim()
        if stream.kickLoggedIn, !kickChannelName.isEmpty {
            channels.append(.init(platform: "kick", name: kickChannelName))
        }
        guard !channels.isEmpty else {
            return
        }
        Task {
            await sendLive(channels: channels)
        }
    }
}
