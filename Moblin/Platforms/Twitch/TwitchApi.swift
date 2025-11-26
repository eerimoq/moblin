import Foundation
import UIKit

private func serialize(_ value: Any) -> Data {
    return (try? JSONSerialization.data(withJSONObject: value))!
}

struct TwitchApiUser: Decodable {
    let id: String
    let login: String
}

struct TwitchApiUsers: Decodable {
    let data: [TwitchApiUser]
}

struct TwitchApiStreamKeyData: Decodable {
    let stream_key: String
}

struct TwitchApiStreamKey: Decodable {
    let data: [TwitchApiStreamKeyData]
}

// periphery:ignore
struct TwitchApiUrls: Decodable {
    let url_1x: String
    let url_2x: String
    let url_4x: String
}

// periphery:ignore
struct TwitchApiChannelPointsCustomRewardsData: Decodable {
    let id: String
    let title: String
    let cost: Int
    let image: TwitchApiUrls?
    let default_image: TwitchApiUrls
    let background_color: String
}

// periphery:ignore
struct TwitchApiChannelPointsCustomRewards: Decodable {
    let data: [TwitchApiChannelPointsCustomRewardsData]
}

struct TwitchApiChannelInformationData: Decodable {
    let title: String
    let game_name: String
}

struct TwitchApiChannelInformation: Decodable {
    let data: [TwitchApiChannelInformationData]
}

struct TwitchApiStartCommercialData: Decodable {
    let message: String
    // periphery:ignore
    let length: Int
    // periphery:ignore
    let retry_after: Int
}

struct TwitchApiStartCommercial: Decodable {
    let data: [TwitchApiStartCommercialData]
}

struct TwitchApiCreateStreamMarkerData: Decodable {}

struct TwitchApiCreateStreamMarker: Decodable {
    let data: [TwitchApiCreateStreamMarkerData]
}

struct TwitchApiStreamData: Decodable {
    let viewer_count: Int
}

struct TwitchApiStreams: Decodable {
    let data: [TwitchApiStreamData]
}

struct TwitchApiGameData: Decodable, Identifiable {
    let id: String
    let name: String
    let box_art_url: String?

    func boxArtUrl(width: Int, height: Int) -> String? {
        return box_art_url?
            .replacingOccurrences(of: "{width}", with: String(width))
            .replacingOccurrences(of: "{height}", with: String(height))
    }
}

struct TwitchApiGames: Decodable {
    let data: [TwitchApiGameData]
}

struct TwitchApiGetBroadcasterSubscriptionsData: Decodable {
    // periphery:ignore
    let user_id: String
    // periphery:ignore
    let user_login: String
    let tier: String

    func tierAsNumber() -> Int {
        return twitchTierAsNumber(tier: tier)
    }
}

struct TwitchApiGetBroadcasterSubscriptions: Decodable {
    let data: [TwitchApiGetBroadcasterSubscriptionsData]
}

// periphery:ignore
struct TwitchApiGetCheermotesDataTiersImagesThemeKind: Decodable {
    let two: String

    private enum CodingKeys: String, CodingKey {
        case two = "2"
    }
}

// periphery:ignore
struct TwitchApiGetCheermotesDataTiersImagesTheme: Decodable {
    let static_: TwitchApiGetCheermotesDataTiersImagesThemeKind

    private enum CodingKeys: String, CodingKey {
        case static_ = "static"
    }
}

// periphery:ignore
struct TwitchApiGetCheermotesDataTiersImages: Decodable {
    let dark: TwitchApiGetCheermotesDataTiersImagesTheme
    let light: TwitchApiGetCheermotesDataTiersImagesTheme
}

// periphery:ignore
struct TwitchApiGetCheermotesDataTier: Decodable {
    let min_bits: Int
    let id: String
    let color: String
    let images: TwitchApiGetCheermotesDataTiersImages
}

// periphery:ignore
struct TwitchApiGetCheermotesData: Decodable {
    let prefix: String
    let tiers: [TwitchApiGetCheermotesDataTier]
}

// periphery:ignore
struct TwitchApiGetCheermotes: Decodable {
    let data: [TwitchApiGetCheermotesData]
}

struct TwitchApiChatBadgesVersion: Decodable {
    let id: String
    let image_url_2x: String
}

struct TwitchApiChatBadgesData: Decodable {
    let set_id: String
    let versions: [TwitchApiChatBadgesVersion]
}

struct TwitchApiChatBadges: Decodable {
    let data: [TwitchApiChatBadgesData]
}

protocol TwitchApiDelegate: AnyObject {
    func twitchApiUnauthorized()
}

func fetchTwitchProfilePicture(username: String) async -> UIImage? {
    guard let url = URL(string: "https://decapi.me/twitch/avatar/\(username)") else {
        return nil
    }
    let request = URLRequest(url: url, timeoutInterval: 10)
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let imageUrlString = String(data: data, encoding: .utf8),
          let profileUrl = URL(string: imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
        return nil
    }
    let imageRequest = URLRequest(url: profileUrl, timeoutInterval: 10)
    guard let (imageData, _) = try? await URLSession.shared.data(for: imageRequest) else {
        return nil
    }
    return UIImage(data: imageData)
}

class TwitchApi {
    private let clientId: String
    private let accessToken: String
    weak var delegate: (any TwitchApiDelegate)?

    init(_ accessToken: String) {
        clientId = twitchMoblinAppClientId
        self.accessToken = accessToken
    }

    func sendChatMessage(broadcasterId: String, message: String, onComplete: @escaping (Bool) -> Void) {
        let body = [
            "broadcaster_id": broadcasterId,
            "sender_id": broadcasterId,
            "message": message,
        ]
        doPost(subPath: "chat/messages", body: serialize(body), onComplete: { data in
            onComplete(data != nil)
        })
    }

    func getUsers(onComplete: @escaping (TwitchApiUsers?) -> Void) {
        doGet(subPath: "users", onComplete: { data in
            onComplete(try? JSONDecoder().decode(TwitchApiUsers.self, from: data ?? Data()))
        })
    }

    func getUserInfo(onComplete: @escaping (TwitchApiUser?) -> Void) {
        getUsers(onComplete: { users in
            onComplete(users?.data.first)
        })
    }

    func createEventSubSubscription(body: String, onComplete: @escaping (Bool) -> Void) {
        doPost(subPath: "eventsub/subscriptions", body: body.utf8Data, onComplete: { data in
            onComplete(data != nil)
        })
    }

    func getStreamKey(broadcasterId: String, onComplete: @escaping (String?) -> Void) {
        doGet(subPath: "streams/key?broadcaster_id=\(broadcasterId)", onComplete: { data in
            let response = try? JSONDecoder().decode(TwitchApiStreamKey.self, from: data ?? Data())
            onComplete(response?.data.first?.stream_key)
        })
    }

    func getChannelPointsCustomRewards(
        broadcasterId: String,
        onComplete: @escaping (TwitchApiChannelPointsCustomRewards?) -> Void
    ) {
        doGet(subPath: "channel_points/custom_rewards?broadcaster_id=\(broadcasterId)", onComplete: { data in
            // logger.info("Twitch rewards: \(String(data: data ?? Data(), encoding: .utf8))")
            let message = try? JSONDecoder().decode(
                TwitchApiChannelPointsCustomRewards.self,
                from: data ?? Data()
            )
            onComplete(message)
        })
    }

    func getChannelInformation(
        broadcasterId: String,
        onComplete: @escaping (TwitchApiChannelInformationData?) -> Void
    ) {
        doGet(subPath: "channels?broadcaster_id=\(broadcasterId)", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiChannelInformation.self,
                from: data ?? Data()
            )
            onComplete(message?.data.first)
        })
    }

    func startCommercial(
        broadcasterId: String,
        length: Int,
        onComplete: @escaping (TwitchApiStartCommercialData?) -> Void
    ) {
        let body: [String: Any] = [
            "broadcaster_id": broadcasterId,
            "length": length,
        ]
        doPost(subPath: "channels/commercial", body: serialize(body), onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiStartCommercial.self,
                from: data ?? Data()
            )
            onComplete(message?.data.first)
        })
    }

    func banUser(broadcasterId: String, userId: String, duration: Int?, onComplete: @escaping (Bool) -> Void) {
        let body: [String: Any]
        if let duration {
            body = [
                "data": [
                    "user_id": userId,
                    "duration": duration,
                ],
            ]
        } else {
            body = [
                "data": [
                    "user_id": userId,
                ],
            ]
        }
        doPost(subPath: "moderation/bans?broadcaster_id=\(broadcasterId)&moderator_id=\(broadcasterId)",
               body: serialize(body),
               onComplete: { data in
                   onComplete(data != nil)
               })
    }

    func deleteChatMessage(broadcasterId: String, messageId: String, onComplete: @escaping (Bool) -> Void) {
        doDelete(
            subPath: """
            moderation/chat\
            ?broadcaster_id=\(broadcasterId)\
            &moderator_id=\(broadcasterId)\
            &message_id=\(messageId)
            """,
            onComplete: { data in
                onComplete(data != nil)
            }
        )
    }

    func createStreamMarker(
        userId: String,
        onComplete: @escaping (TwitchApiCreateStreamMarkerData?) -> Void
    ) {
        let body = [
            "user_id": userId,
        ]
        doPost(subPath: "streams/markers", body: serialize(body), onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiCreateStreamMarker.self,
                from: data ?? Data()
            )
            onComplete(message?.data.first)
        })
    }

    func getStream(userId: String, onComplete: @escaping (TwitchApiStreamData?) -> Void) {
        doGet(subPath: "streams?user_id=\(userId)", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiStreams.self,
                from: data ?? Data()
            )
            onComplete(message?.data.first)
        })
    }

    func getGames(names: [String], onComplete: @escaping ([TwitchApiGameData]?) -> Void) {
        var components = URLComponents()
        components.queryItems = names.map { URLQueryItem(name: "name", value: $0) }
        guard let query = components.percentEncodedQuery else {
            return
        }
        doGet(subPath: "games?\(query)", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiGames.self,
                from: data ?? Data()
            )
            onComplete(message?.data)
        })
    }

    func searchCategories(query: String, onComplete: @escaping ([TwitchApiGameData]?) -> Void) {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "first", value: "10"),
        ]
        guard let query = components.percentEncodedQuery else {
            return
        }
        doGet(subPath: "search/categories?\(query)", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiGames.self,
                from: data ?? Data()
            )
            onComplete(message?.data)
        })
    }

    func modifyChannelInformation(broadcasterId: String,
                                  categoryId: String?,
                                  title: String?,
                                  onComplete: @escaping (Bool) -> Void)
    {
        var body: [String: String] = [:]
        if let categoryId {
            body["game_id"] = categoryId
        }
        if let title {
            body["title"] = title
        }
        doPatch(
            subPath: "channels?broadcaster_id=\(broadcasterId)",
            body: serialize(body),
            onComplete: { data in
                onComplete(data != nil)
            }
        )
    }

    func getGlobalChatBadges(onComplete: @escaping ([TwitchApiChatBadgesData]?) -> Void) {
        doGet(subPath: "chat/badges/global", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiChatBadges.self,
                from: data ?? Data()
            )
            onComplete(message?.data)
        })
    }

    func getChannelChatBadges(
        broadcasterId: String,
        onComplete: @escaping ([TwitchApiChatBadgesData]?) -> Void
    ) {
        doGet(subPath: "chat/badges?broadcaster_id=\(broadcasterId)", onComplete: { data in
            let message = try? JSONDecoder().decode(
                TwitchApiChatBadges.self,
                from: data ?? Data()
            )
            onComplete(message?.data)
        })
    }

    func getBroadcasterSubscriptions(
        broadcasterId: String,
        userId: String,
        onComplete: @escaping (TwitchApiGetBroadcasterSubscriptionsData?) -> Void
    ) {
        doGet(
            subPath: "subscriptions?broadcaster_id=\(broadcasterId)&user_id=\(userId)",
            onComplete: { data in
                let message = try? JSONDecoder().decode(
                    TwitchApiGetBroadcasterSubscriptions.self,
                    from: data ?? Data()
                )
                onComplete(message?.data.first)
            }
        )
    }

    func getCheermotes(
        broadcasterId: String,
        onComplete: @escaping ([TwitchApiGetCheermotesData]?) -> Void
    ) {
        doGet(
            subPath: "bits/cheermotes?broadcaster_id=\(broadcasterId)",
            onComplete: { data in
                let message = try? JSONDecoder().decode(
                    TwitchApiGetCheermotes.self,
                    from: data ?? Data()
                )
                onComplete(message?.data)
            }
        )
    }

    private func doGet(subPath: String, onComplete: @escaping ((Data?) -> Void)) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        let request = createGetRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if response?.http?.isUnauthorized == true {
                        self.delegate?.twitchApiUnauthorized()
                    }
                    onComplete(nil)
                    return
                }
                onComplete(data)
            }
        }
        .resume()
    }

    private func doPost(subPath: String, body: Data, onComplete: @escaping (Data?) -> Void) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        var request = createPostRequest(url: url)
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if response?.http?.isUnauthorized == true {
                        self.delegate?.twitchApiUnauthorized()
                    }
                    if let data, let data = String(bytes: data, encoding: .utf8) {
                        logger.info("twitch-api: Error response body: \(data)")
                    }
                    onComplete(nil)
                    return
                }
                onComplete(data)
            }
        }
        .resume()
    }

    private func doPatch(subPath: String, body: Data, onComplete: @escaping (Data?) -> Void) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        var request = createPatchRequest(url: url)
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if response?.http?.isUnauthorized == true {
                        self.delegate?.twitchApiUnauthorized()
                    }
                    onComplete(nil)
                    return
                }
                onComplete(data)
            }
        }
        .resume()
    }

    private func doDelete(subPath: String, onComplete: @escaping (Data?) -> Void) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        let request = createDeleteRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if response?.http?.isUnauthorized == true {
                        self.delegate?.twitchApiUnauthorized()
                    }
                    onComplete(nil)
                    return
                }
                onComplete(data)
            }
        }
        .resume()
    }

    private func createGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setAuthorization("Bearer \(accessToken)")
        return request
    }

    private func createPostRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setAuthorization("Bearer \(accessToken)")
        request.setContentType("application/json")
        return request
    }

    private func createPatchRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setAuthorization("Bearer \(accessToken)")
        request.setContentType("application/json")
        return request
    }

    private func createDeleteRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setAuthorization("Bearer \(accessToken)")
        return request
    }
}
