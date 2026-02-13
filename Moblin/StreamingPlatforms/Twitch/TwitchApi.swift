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

struct TwitchApiChannelPointsCustomRewardsData: Decodable {
    let id: String
    let title: String
}

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
    // periphery:ignore
    let length: Int
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

struct TwitchApiChannel: Decodable, Identifiable {
    let id: String
    let broadcaster_login: String
    let display_name: String
    let game_name: String
    let title: String
    let thumbnail_url: String
}

struct TwitchApiSearchChannels: Decodable {
    let data: [TwitchApiChannel]
}

struct TwitchApiGetBroadcasterSubscriptionsData: Decodable {
    let tier: String

    func tierAsNumber() -> Int {
        return twitchTierAsNumber(tier: tier)
    }
}

struct TwitchApiGetBroadcasterSubscriptions: Decodable {
    let data: [TwitchApiGetBroadcasterSubscriptionsData]
}

struct TwitchApiGetCheermotesDataTiersImagesThemeKind: Decodable {
    let two: String

    private enum CodingKeys: String, CodingKey {
        case two = "2"
    }
}

struct TwitchApiGetCheermotesDataTiersImagesTheme: Decodable {
    let static_: TwitchApiGetCheermotesDataTiersImagesThemeKind

    private enum CodingKeys: String, CodingKey {
        case static_ = "static"
    }
}

struct TwitchApiGetCheermotesDataTiersImages: Decodable {
    let dark: TwitchApiGetCheermotesDataTiersImagesTheme
}

struct TwitchApiGetCheermotesDataTier: Decodable {
    let min_bits: Int
    let images: TwitchApiGetCheermotesDataTiersImages
}

struct TwitchApiGetCheermotesData: Decodable {
    // periphery: ignore
    let prefix: String
    let tiers: [TwitchApiGetCheermotesDataTier]
}

struct TwitchApiGetCheermotes: Decodable {
    let data: [TwitchApiGetCheermotesData]
}

struct TwitchApiChatBadgesVersion: Decodable {
    // periphery: ignore
    let id: String
    let image_url_2x: String
}

struct TwitchApiChatBadgesData: Decodable {
    // periphery: ignore
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

    func sendChatMessage(broadcasterId: String,
                         message: String,
                         onComplete: @escaping (OperationResult) -> Void)
    {
        let body = [
            "broadcaster_id": broadcasterId,
            "sender_id": broadcasterId,
            "message": message,
        ]
        doPost(subPath: "chat/messages", body: serialize(body), onComplete: onComplete)
    }

    func getUsers(onComplete: @escaping (TwitchApiUsers?) -> Void) {
        doGet(subPath: "users") {
            switch $0 {
            case let .success(data):
                onComplete(try? JSONDecoder().decode(TwitchApiUsers.self, from: data))
            default:
                onComplete(nil)
            }
        }
    }

    func getUserInfo(onComplete: @escaping (TwitchApiUser?) -> Void) {
        getUsers { users in
            onComplete(users?.data.first)
        }
    }

    func getUserByLogin(login: String, onComplete: @escaping (TwitchApiUser?) -> Void) {
        doGet(subPath: makeUrl("users", [("login", login)])) {
            switch $0 {
            case let .success(data):
                let users = try? JSONDecoder().decode(TwitchApiUsers.self, from: data)
                onComplete(users?.data.first)
            default:
                onComplete(nil)
            }
        }
    }

    func createEventSubSubscription(body: String, onComplete: @escaping (Bool) -> Void) {
        doPost(subPath: "eventsub/subscriptions", body: body.utf8Data) {
            onComplete($0.isSuccessful())
        }
    }

    func getStreamKey(broadcasterId: String, onComplete: @escaping (String?) -> Void) {
        doGet(subPath: makeUrl("streams/key", [("broadcaster_id", broadcasterId)])) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(TwitchApiStreamKey.self, from: data)
                onComplete(response?.data.first?.stream_key)
            default:
                onComplete(nil)
            }
        }
    }

    func getChannelPointsCustomRewards(
        broadcasterId: String,
        onComplete: @escaping (TwitchApiChannelPointsCustomRewards?) -> Void
    ) {
        doGet(subPath: makeUrl("channel_points/custom_rewards", [("broadcaster_id", broadcasterId)])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiChannelPointsCustomRewards.self, from: data)
                onComplete(message)
            default:
                onComplete(nil)
            }
        }
    }

    func getChannelInformation(
        broadcasterId: String,
        onComplete: @escaping (TwitchApiChannelInformationData?) -> Void
    ) {
        doGet(subPath: makeUrl("channels", [("broadcaster_id", broadcasterId)])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiChannelInformation.self, from: data)
                onComplete(message?.data.first)
            default:
                onComplete(nil)
            }
        }
    }

    func startCommercial(
        broadcasterId: String,
        length: Int,
        onComplete: @escaping (NetworkResponse<TwitchApiStartCommercialData>) -> Void
    ) {
        let body: [String: Any] = [
            "broadcaster_id": broadcasterId,
            "length": length,
        ]
        doPost(subPath: "channels/commercial", body: serialize(body)) {
            switch $0 {
            case let .success(data):
                if let message = (try? JSONDecoder().decode(TwitchApiStartCommercial.self, from: data))?.data
                    .first
                {
                    onComplete(.success(message))
                } else {
                    onComplete(.error)
                }
            case .authError:
                onComplete(.authError)
            case .error:
                onComplete(.error)
            }
        }
    }

    func banUser(
        broadcasterId: String,
        userId: String,
        duration: Int?,
        reason: String?,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        var data: [String: Any] = ["user_id": userId]
        if let duration {
            data["duration"] = duration
        }
        if let reason {
            data["reason"] = reason
        }
        let subPath = makeUrl(
            "moderation/bans",
            [
                ("broadcaster_id", broadcasterId),
                ("moderator_id", broadcasterId),
            ]
        )
        doPost(subPath: subPath, body: serialize(["data": data]), onComplete: onComplete)
    }

    func unbanUser(broadcasterId: String, userId: String, onComplete: @escaping (OperationResult) -> Void) {
        let subPath = makeUrl(
            "moderation/bans",
            [
                ("broadcaster_id", broadcasterId),
                ("moderator_id", broadcasterId),
                ("user_id", userId),
            ]
        )
        doDelete(subPath: subPath, onComplete: onComplete)
    }

    func addModerator(broadcasterId: String, userId: String,
                      onComplete: @escaping (OperationResult) -> Void)
    {
        let subPath = makeUrl(
            "moderation/moderators",
            [
                ("broadcaster_id", broadcasterId),
                ("user_id", userId),
            ]
        )
        doPost(subPath: subPath, body: Data(), onComplete: onComplete)
    }

    func removeModerator(
        broadcasterId: String,
        userId: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        let subPath = makeUrl(
            "moderation/moderators",
            [
                ("broadcaster_id", broadcasterId),
                ("user_id", userId),
            ]
        )
        doDelete(subPath: subPath, onComplete: onComplete)
    }

    func addVip(broadcasterId: String, userId: String, onComplete: @escaping (OperationResult) -> Void) {
        let subPath = makeUrl("channels/vips", [("broadcaster_id", broadcasterId), ("user_id", userId)])
        doPost(subPath: subPath, body: Data(), onComplete: onComplete)
    }

    func removeVip(broadcasterId: String, userId: String, onComplete: @escaping (OperationResult) -> Void) {
        let subPath = makeUrl("channels/vips", [("broadcaster_id", broadcasterId), ("user_id", userId)])
        doDelete(subPath: subPath, onComplete: onComplete)
    }

    func sendAnnouncement(broadcasterId: String,
                          message: String,
                          color: String,
                          onComplete: @escaping (OperationResult) -> Void)
    {
        let subPath = makeUrl(
            "chat/announcements",
            [
                ("broadcaster_id", broadcasterId),
                ("moderator_id", broadcasterId),
            ]
        )
        let body: [String: Any] = [
            "message": message,
            "color": color,
        ]
        doPost(subPath: subPath, body: serialize(body), onComplete: onComplete)
    }

    func updateChatSettings(
        broadcasterId: String,
        settings: [String: Any],
        onComplete: @escaping (OperationResult) -> Void
    ) {
        let subPath = makeUrl(
            "chat/settings",
            [
                ("broadcaster_id", broadcasterId),
                ("moderator_id", broadcasterId),
            ]
        )
        doPatch(subPath: subPath, body: serialize(settings), onComplete: onComplete)
    }

    func deleteChatMessage(broadcasterId: String, messageId: String, onComplete: @escaping (Bool) -> Void) {
        let subPath = makeUrl(
            "moderation/chat",
            [
                ("broadcaster_id", broadcasterId),
                ("moderator_id", broadcasterId),
                ("message_id", messageId),
            ]
        )
        doDelete(subPath: subPath, onComplete: { onComplete($0.isSuccessful()) })
    }

    func createStreamMarker(
        userId: String,
        onComplete: @escaping (TwitchApiCreateStreamMarkerData?) -> Void
    ) {
        let body = [
            "user_id": userId,
        ]
        doPost(subPath: "streams/markers", body: serialize(body)) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiCreateStreamMarker.self, from: data)
                onComplete(message?.data.first)
            default:
                onComplete(nil)
            }
        }
    }

    func getStream(userId: String, onComplete: @escaping (NetworkResponse<TwitchApiStreamData?>) -> Void) {
        doGet(subPath: makeUrl("streams", [("user_id", userId), ("type", "live")])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiStreams.self, from: data)
                onComplete(.success(message?.data.first))
            case .authError:
                onComplete(.authError)
            case .error:
                onComplete(.error)
            }
        }
    }

    func getGames(names: [String], onComplete: @escaping ([TwitchApiGameData]?) -> Void) {
        doGet(subPath: makeUrl("games", names.map { ("name", $0) })) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiGames.self, from: data)
                onComplete(message?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func startRaid(
        broadcasterId: String,
        toBroadcasterId: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        let subPath = makeUrl(
            "raids",
            [("from_broadcaster_id", broadcasterId), ("to_broadcaster_id", toBroadcasterId)]
        )
        doPost(subPath: subPath, body: Data(), onComplete: onComplete)
    }

    func cancelRaid(
        broadcasterId: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        doDelete(subPath: makeUrl("raids", [("broadcaster_id", broadcasterId)])) {
            onComplete($0)
        }
    }

    func searchCategories(query: String, onComplete: @escaping ([TwitchApiGameData]?) -> Void) {
        doGet(subPath: makeUrl("search/categories", [("query", query), ("first", "10")])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiGames.self, from: data)
                onComplete(message?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func searchChannel(channelName: String, onComplete: @escaping (TwitchApiChannel?) -> Void) {
        searchChannels(filter: channelName, liveOnly: false) {
            switch $0 {
            case let .success(data):
                onComplete(data.first(where: {
                    $0.broadcaster_login.lowercased() == channelName.lowercased()
                }))
            default:
                onComplete(nil)
            }
        }
    }

    func searchChannels(filter: String,
                        liveOnly: Bool,
                        onComplete: @escaping (NetworkResponse<[TwitchApiChannel]>) -> Void)
    {
        var parameters = [("query", filter)]
        if liveOnly {
            parameters.append(("live_only", "true"))
        }
        doGet(subPath: makeUrl("search/channels", parameters)) {
            switch $0 {
            case let .success(data):
                if let message = try? JSONDecoder().decode(TwitchApiSearchChannels.self, from: data) {
                    onComplete(.success(message.data))
                } else {
                    onComplete(.error)
                }
            case .authError:
                onComplete(.authError)
            case .error:
                onComplete(.error)
            }
        }
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
            subPath: makeUrl("channels", [("broadcaster_id", broadcasterId)]),
            body: serialize(body),
            onComplete: {
                onComplete($0.isSuccessful())
            }
        )
    }

    func getGlobalChatBadges(onComplete: @escaping ([TwitchApiChatBadgesData]?) -> Void) {
        doGet(subPath: "chat/badges/global") {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiChatBadges.self, from: data)
                onComplete(message?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func getChannelChatBadges(
        broadcasterId: String,
        onComplete: @escaping ([TwitchApiChatBadgesData]?) -> Void
    ) {
        doGet(subPath: makeUrl("chat/badges", [("broadcaster_id", broadcasterId)])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiChatBadges.self, from: data)
                onComplete(message?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func getBroadcasterSubscriptions(
        broadcasterId: String,
        userId: String,
        onComplete: @escaping (TwitchApiGetBroadcasterSubscriptionsData?) -> Void
    ) {
        doGet(subPath: makeUrl("subscriptions", [("broadcaster_id", broadcasterId), ("user_id", userId)])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiGetBroadcasterSubscriptions.self, from: data)
                onComplete(message?.data.first)
            default:
                onComplete(nil)
            }
        }
    }

    func getCheermotes(
        broadcasterId: String,
        onComplete: @escaping ([TwitchApiGetCheermotesData]?) -> Void
    ) {
        doGet(subPath: makeUrl("bits/cheermotes", [("broadcaster_id", broadcasterId)])) {
            switch $0 {
            case let .success(data):
                let message = try? JSONDecoder().decode(TwitchApiGetCheermotes.self, from: data)
                onComplete(message?.data)
            default:
                onComplete(nil)
            }
        }
    }

    private func doGet(subPath: String, onComplete: @escaping ((OperationResult) -> Void)) {
        doRequest(createRequest(url: makeHelixUrl(subPath: subPath), method: "GET"), onComplete)
    }

    private func doPost(subPath: String, body: Data, onComplete: @escaping (OperationResult) -> Void) {
        var request = createRequest(url: makeHelixUrl(subPath: subPath), method: "POST", json: true)
        request.httpBody = body
        doRequest(request, onComplete)
    }

    private func doPatch(subPath: String, body: Data, onComplete: @escaping (OperationResult) -> Void) {
        var request = createRequest(url: makeHelixUrl(subPath: subPath), method: "PATCH", json: true)
        request.httpBody = body
        doRequest(request, onComplete)
    }

    private func doDelete(subPath: String, onComplete: @escaping (OperationResult) -> Void) {
        doRequest(createRequest(url: makeHelixUrl(subPath: subPath), method: "DELETE"), onComplete)
    }

    private func makeHelixUrl(subPath: String) -> URL {
        return URL(string: "https://api.twitch.tv/helix/\(subPath)")!
    }

    private func doRequest(_ request: URLRequest, _ onComplete: @escaping (OperationResult) -> Void) {
        httpRequest(request: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                if let data, let data = String(bytes: data, encoding: .utf8) {
                    logger.info("twitch-api: Error response body: \(data)")
                }
                if response?.http?.isUnauthorized == true {
                    self.delegate?.twitchApiUnauthorized()
                    onComplete(.authError)
                } else {
                    onComplete(.error)
                }
                return
            }
            onComplete(.success(data))
        }
    }

    private func createRequest(url: URL, method: String, json: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setAuthorization("Bearer \(accessToken)")
        if json {
            request.setContentType("application/json")
        }
        return request
    }
}
