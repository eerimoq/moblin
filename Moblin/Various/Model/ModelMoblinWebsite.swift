import CryptoKit
import DeviceCheck
import Foundation
import UIKit

private let liveUrl = URL(string: "https://api.moblin.app/streamers/live")!
private let challengeUrl = URL(string: "https://api.moblin.app/streamers/live/challenge")!
private let appAttestStorage = SimpleStringStorage(key: "moblinWebsiteAppAttest")

private struct MoblinWebsiteChannel: Encodable {
    let platform: String
    let name: String
}

private struct MoblinWebsiteLive: Encodable {
    let channels: [MoblinWebsiteChannel]
    let image: String?
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

private func postLive(channels: [MoblinWebsiteChannel],
                      image: String?,
                      appAttest: MoblinWebsiteAppAttest) async throws
{
    let challenge = try await fetchChallenge()
    let live = MoblinWebsiteLive(
        channels: channels,
        image: image,
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

private func sendLive(channels: [MoblinWebsiteChannel], image: String?) async {
    guard DCAppAttestService.shared.isSupported else {
        logger.info("moblin-website: App Attest is not supported on this device")
        return
    }
    do {
        let attestedBefore = loadAppAttest()?.attestation != nil
        do {
            try await postLive(channels: channels, image: image, appAttest: attestedKey())
        } catch let MoblinWebsiteError.keyRejected(reason) where attestedBefore {
            logger.info("moblin-website: Key rejected (\(reason)), attesting a new one")
            storeAppAttest(nil)
            try await postLive(channels: channels, image: image, appAttest: attestedKey())
        }
    } catch {
        logger.info("moblin-website: Failed to send live: \(error)")
    }
}

private func encodeImage(_ image: UIImage) -> String? {
    var image = image
    let maxDimension = image.size.maximum()
    if maxDimension > 320 {
        image = image.resize(height: image.size.height * 320 / maxDimension)
    }
    return image.jpegData(compressionQuality: 0.8)?.base64EncodedString()
}

extension Model {
    func sendLiveToMoblinWebsite(snapshot: UIImage?, onCompleted: (@MainActor () -> Void)? = nil) {
        guard !isMac(), stream.goLiveNotificationMoblinWebsite else {
            onCompleted?()
            return
        }
        let stream = stream
        let image = snapshot.flatMap(encodeImage)
        Task {
            defer {
                onCompleted?()
            }
            var channels: [MoblinWebsiteChannel] = []
            if stream.twitchLoggedIn, let name = await fetchTwitchChannelName(stream: stream), !name.isEmpty {
                channels.append(.init(platform: "twitch", name: name))
            }
            if stream.isYouTubeAuthorized(), let name = await fetchYouTubeHandle(stream: stream),
               !name.isEmpty
            {
                channels.append(.init(platform: "youtube", name: name))
            }
            if stream.kickLoggedIn, let name = await fetchKickChannelName(stream: stream), !name.isEmpty {
                channels.append(.init(platform: "kick", name: name))
            }
            guard !channels.isEmpty else {
                return
            }
            await sendLive(channels: channels, image: image)
        }
    }

    private func fetchTwitchChannelName(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            createTwitchApi(stream: stream).getUserInfo { info in
                continuation.resume(returning: info?.login.trim())
            }
        }
    }

    private func fetchYouTubeHandle(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            getYouTubeApi(stream: stream) { youTubeApi in
                guard let youTubeApi else {
                    continuation.resume(returning: nil)
                    return
                }
                youTubeApi.listChannels {
                    switch $0 {
                    case let .success(response):
                        let handle = response.items.first?.snippet.customUrl?.trim().trimmingPrefix("@")
                        continuation.resume(returning: handle.map { String($0) })
                    case .authError, .error:
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func fetchKickChannelName(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            createKickApi(stream: stream).getUser { user in
                continuation.resume(returning: user?.username.trim())
            }
        }
    }
}
