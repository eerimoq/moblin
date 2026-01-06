import Foundation
import UIKit

struct BadgeImage: Codable {
    let src: String
    // periphery:ignore
    let srcset: String
}

struct SubscriberBadge: Codable {
    // periphery:ignore
    let id: Int
    // periphery:ignore
    let channel_id: Int
    let months: Int
    let badge_image: BadgeImage
}

struct KickLivestreamCategory: Codable {
    let name: String?
}

struct KickLivestream: Codable {
    // periphery:ignore
    let id: Int
    let viewers: Int
    let session_title: String?
    let categories: [KickLivestreamCategory]?
}

struct KickChatroom: Codable {
    let id: Int
    let channel_id: Int
}

struct KickChannelUser: Codable {
    let username: String?
    let profile_pic: String?
}

struct KickChannel: Codable {
    let slug: String
    let chatroom: KickChatroom
    let livestream: KickLivestream?
    let subscriber_badges: [SubscriberBadge]?
    let user: KickChannelUser?
}

struct KickUser: Codable {
    let username: String
}

struct KickCategory: Codable, Identifiable {
    let id: String
    // periphery:ignore
    let category_id: Int
    let name: String
    // periphery:ignore
    let slug: String
    let src: String?
    // periphery:ignore
    let srcset: String?
}

struct KickFollowedChannel: Codable, Identifiable {
    var id: String { channel_slug }
    let is_live: Bool
    let profile_picture: String?
    let channel_slug: String
    let viewer_count: Int?
    let category_name: String?
    let user_username: String
    let session_title: String?
}

struct KickFollowedChannelsResponse: Codable {
    let channels: [KickFollowedChannel]
    let nextCursor: Int?
}

struct KickHostChannelResponse: Codable {
    let success: Bool
}

struct KickCategorySearchHit: Codable {
    let document: KickCategory
}

struct KickCategorySearchResponse: Codable {
    // periphery:ignore
    let found: Int
    let hits: [KickCategorySearchHit]
}

struct KickStreamInfo {
    let title: String
    let categoryName: String?
}

private let userUrl = URL(string: "https://kick.com/api/v1/user")!

func getKickChannelInfo(channelName: String) async throws -> KickChannel {
    guard let url = URL(string: "https://kick.com/api/v1/channels/\(channelName)") else {
        throw "Invalid URL"
    }
    let (data, response) = try await httpGet(from: url)
    if !response.isSuccessful {
        throw "Not successful"
    }
    return try JSONDecoder().decode(KickChannel.self, from: data)
}

func getKickChannelInfo(channelName: String, onComplete: @escaping (KickChannel?) -> Void) {
    guard let url = URL(string: "https://kick.com/api/v1/channels/\(channelName)") else {
        onComplete(nil)
        return
    }
    let request = URLRequest(url: url)
    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil)
                return
            }
            onComplete(try? JSONDecoder().decode(KickChannel.self, from: data))
        }
    }
    .resume()
}

func getKickUser(accessToken: String, onComplete: @escaping (KickUser?) -> Void) {
    var request = URLRequest(url: userUrl)
    request.setAuthorization("Bearer \(accessToken)")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil)
                return
            }
            onComplete(try? JSONDecoder().decode(KickUser.self, from: data))
        }
    }
    .resume()
}

func getKickFollowedChannels(
    accessToken: String,
    cursor: Int? = nil,
    onComplete: @escaping (KickFollowedChannelsResponse?) -> Void
) {
    var urlString = "https://kick.com/api/v2/channels/followed"
    if let cursor {
        urlString += "?cursor=\(cursor)"
    }
    guard let url = URL(string: urlString) else {
        onComplete(nil)
        return
    }
    var request = URLRequest(url: url)
    request.setAuthorization("Bearer \(accessToken)")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil)
                return
            }
            onComplete(try? JSONDecoder().decode(KickFollowedChannelsResponse.self, from: data))
        }
    }
    .resume()
}

func fetchKickProfilePicture(username: String) async -> UIImage? {
    if let image = await fetchKickProfilePictureWithUsername(username) {
        return image
    }
    if username.contains("_") {
        let kebabUsername = username.replacingOccurrences(of: "_", with: "-")
        return await fetchKickProfilePictureWithUsername(kebabUsername)
    }
    return nil
}

private func fetchKickProfilePictureWithUsername(_ username: String) async -> UIImage? {
    guard let channelInfo = try? await getKickChannelInfo(channelName: username),
          let profilePic = channelInfo.user?.profile_pic,
          let imageUrl = URL(string: profilePic)
    else {
        return nil
    }
    guard let (data, response) = try? await httpGet(from: imageUrl) else {
        return nil
    }
    if !response.isSuccessful {
        return nil
    }
    return UIImage(data: data)
}

class KickApi {
    private let channelId: String
    private let slug: String
    private let accessToken: String

    init(channelId: String, slug: String, accessToken: String) {
        self.channelId = channelId
        self.slug = slug
        self.accessToken = accessToken
    }

    func sendMessage(message: String) {
        doV2Request(method: "POST",
                    subPath: "messages/send/\(channelId)",
                    body: ["type": "message", "content": message])
        { _ in }
    }

    func deleteMessage(messageId: String) {
        doV2Request(method: "DELETE",
                    subPath: "chatrooms/\(channelId)/messages/\(messageId)")
        { _ in }
    }

    func banUser(user: String,
                 duration: Int? = nil,
                 reason: String? = nil,
                 onComplete: @escaping (OperationResult) -> Void)
    {
        var body: [String: Any] = [
            "banned_username": user,
            "permanent": duration == nil,
        ]
        if let duration {
            body["duration"] = duration / 60
        }
        if let reason {
            body["reason"] = reason
        }
        doV2Request(method: "POST",
                    subPath: "channels/\(slug)/bans",
                    body: body,
                    onComplete: onComplete)
    }

    func unbanUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "DELETE",
                    subPath: "channels/\(slug)/bans/\(user)",
                    onComplete: onComplete)
    }

    func addModerator(user: String, onComplete: @escaping (OperationResult) -> Void) {
        doInternalV1Request(method: "POST",
                            subPath: "channels/\(slug)/community/moderators",
                            body: ["username": user],
                            onComplete: onComplete)
    }

    func removeModerator(user: String, onComplete: @escaping (OperationResult) -> Void) {
        doInternalV1Request(method: "DELETE",
                            subPath: "channels/\(slug)/community/moderators/\(user)",
                            onComplete: onComplete)
    }

    func addVip(user: String, onComplete: @escaping (OperationResult) -> Void) {
        doInternalV1Request(method: "POST",
                            subPath: "channels/\(slug)/community/vips",
                            body: ["username": user],
                            onComplete: onComplete)
    }

    func removeVip(user: String, onComplete: @escaping (OperationResult) -> Void) {
        doInternalV1Request(method: "DELETE",
                            subPath: "channels/\(slug)/community/vips/\(user)",
                            onComplete: onComplete)
    }

    func hostChannel(channel: String, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "POST",
                    subPath: "channels/\(slug)/chat-commands",
                    body: ["command": "host", "parameter": channel])
        { result in
            switch result {
            case let .success(data):
                if let response = try? JSONDecoder().decode(KickHostChannelResponse.self, from: data) {
                    onComplete(response.success ? .success(data) : .error)
                } else {
                    onComplete(.success(data))
                }
            case .authError:
                onComplete(.authError)
            case .error:
                onComplete(.error)
            }
        }
    }

    func enableSlowMode(messageInterval: Int, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: ["slow_mode": true, "message_interval": messageInterval],
                    onComplete: onComplete)
    }

    func disableSlowMode(onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: ["slow_mode": false],
                    onComplete: onComplete)
    }

    func enableFollowersMode(minimumDuration: Int, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: [
                        "followers_mode": true,
                        "following_min_duration": minimumDuration,
                    ],
                    onComplete: onComplete)
    }

    func disableFollowersMode(onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: ["followers_mode": false],
                    onComplete: onComplete)
    }

    func setEmoteOnlyMode(enabled: Bool, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: ["emotes_mode": enabled],
                    onComplete: onComplete)
    }

    func setSubscribersOnlyMode(enabled: Bool, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PUT",
                    subPath: "channels/\(slug)/chatroom",
                    body: ["subscribers_mode": enabled],
                    onComplete: onComplete)
    }

    func createPoll(
        title: String,
        options: [String],
        duration: Int,
        resultDisplayDuration: Int,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        let body: [String: Any] = [
            "title": title,
            "options": options,
            "duration": duration,
            "result_display_duration": resultDisplayDuration,
        ]
        doV2Request(method: "POST",
                    subPath: "channels/\(slug)/polls",
                    body: body,
                    onComplete: onComplete)
    }

    func deletePoll(onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "DELETE",
                    subPath: "channels/\(slug)/polls",
                    onComplete: onComplete)
    }

    func createPrediction(title: String,
                          outcomes: [String],
                          duration: Int,
                          onComplete: @escaping (OperationResult) -> Void)
    {
        let body: [String: Any] = [
            "title": title,
            "outcomes": outcomes,
            "duration": duration,
        ]
        doV2Request(method: "POST",
                    subPath: "channels/\(slug)/predictions",
                    body: body,
                    onComplete: onComplete)
    }

    func getStreamInfo(onComplete: @escaping (NetworkResponse<KickStreamInfo>) -> Void) {
        doV2Request(method: "GET", subPath: "channels/\(slug)/stream-info") { result in
            switch result {
            case let .success(data):
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let title = json["stream_title"] as? String
                else {
                    onComplete(.error)
                    return
                }
                var categoryName: String?
                if let category = json["category"] as? [String: Any] {
                    categoryName = category["name"] as? String
                }
                onComplete(.success(KickStreamInfo(title: title, categoryName: categoryName)))
            case .authError:
                onComplete(.authError)
            case .error:
                onComplete(.error)
            }
        }
    }

    func setStreamTitle(title: String, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PATCH",
                    subPath: "channels/\(slug)/stream-info",
                    body: ["stream_title": title],
                    onComplete: onComplete)
    }

    func setStreamCategory(categoryId: Int, onComplete: @escaping (OperationResult) -> Void) {
        doV2Request(method: "PATCH",
                    subPath: "channels/\(slug)/stream-info",
                    body: ["category_id": categoryId],
                    onComplete: onComplete)
    }

    func searchCategories(query: String, onComplete: @escaping ([KickCategory]?) -> Void) {
        guard var components =
            URLComponents(string: "https://search.kick.com/collections/subcategory_index/documents/search")
        else {
            onComplete(nil)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query_by", value: "name"),
        ]
        guard let url = components.url else {
            onComplete(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("nXIMW0iEN6sMujFYjFuhdrSwVow3pDQu", forHTTPHeaderField: "X-Typesense-Api-Key")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data,
                      response?.http?.isSuccessful == true,
                      let searchResponse = try? JSONDecoder().decode(
                          KickCategorySearchResponse.self,
                          from: data
                      )
                else {
                    onComplete(nil)
                    return
                }
                let categories = searchResponse.hits.map { $0.document }
                onComplete(categories)
            }
        }
        .resume()
    }

    private func doV2Request(method: String,
                             subPath: String,
                             body: [String: Any]? = nil,
                             onComplete: @escaping (OperationResult) -> Void)
    {
        doRequest(method: method, subPath: "v2/\(subPath)", body: body, onComplete: onComplete)
    }

    private func doInternalV1Request(method: String,
                                     subPath: String,
                                     body: [String: Any]? = nil,
                                     onComplete: @escaping (OperationResult) -> Void)
    {
        doRequest(method: method, subPath: "internal/v1/\(subPath)", body: body, onComplete: onComplete)
    }

    private func doRequest(method: String,
                           subPath: String,
                           body: [String: Any]? = nil,
                           onComplete: @escaping (OperationResult) -> Void)
    {
        guard let url = URL(string: "https://kick.com/api/\(subPath)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setContentType("application/json")
        request.setAuthorization("Bearer \(accessToken)")
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if let data, let data = String(bytes: data, encoding: .utf8) {
                        logger.info("kick-api: Error response body: \(data)")
                    }
                    if response?.http?.isUnauthorized == true {
                        onComplete(.authError)
                    } else {
                        onComplete(.error)
                    }
                    return
                }
                onComplete(.success(data))
            }
        }
        .resume()
    }
}
