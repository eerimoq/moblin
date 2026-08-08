import Foundation

// VK Video Live DevAPI. See https://dev.live.vkvideo.ru/docs/ for details.
private let apiUrl = "https://apidev.live.vkvideo.ru"

struct VkVideoLiveBadge: Decodable {
    let id: String
    let name: String?
    let achievement_name: String?
    let small_url: String?
    let medium_url: String?
    let large_url: String?
}

struct VkVideoLiveRole: Decodable {
    let id: String
    let name: String?
    let small_url: String?
    let medium_url: String?
    let large_url: String?
}

struct VkVideoLiveMessageAuthor: Decodable {
    let avatar_url: String?
    let badges: [VkVideoLiveBadge]?
    let id: Int64
    let is_moderator: Bool?
    let is_owner: Bool?
    let nick: String
    let nick_color: Int?
    let roles: [VkVideoLiveRole]?
}

struct VkVideoLiveContentLink: Decodable {
    let content: String?
    let url: String?
}

struct VkVideoLiveContentMention: Decodable {
    let id: Int64?
    let nick: String?
}

struct VkVideoLiveContentSmile: Decodable {
    let animated: Bool?
    let id: String?
    let large_url: String?
    let medium_url: String?
    let name: String?
    let small_url: String?
}

struct VkVideoLiveContentText: Decodable {
    let content: String?
}

struct VkVideoLiveMessagePart: Decodable {
    let link: VkVideoLiveContentLink?
    let mention: VkVideoLiveContentMention?
    let smile: VkVideoLiveContentSmile?
    let text: VkVideoLiveContentText?
}

struct VkVideoLiveChatMessage: Decodable {
    let author: VkVideoLiveMessageAuthor
    let created_at: Int64?
    let id: Int64?
    let is_private: Bool?
    let parts: [VkVideoLiveMessagePart]
}

struct VkVideoLiveWebSocketChannels: Decodable {
    let channel_points: String?
    let chat: String?
    let info: String?
    let limited_chat: String?
    let limited_private_chat: String?
    let private_channel_points: String?
    let private_chat: String?
    let private_info: String?
}

struct VkVideoLiveChannel: Decodable {
    let avatar_url: String?
    let id: Int64?
    let nick: String?
    let status: String?
    let url: String?
    let web_socket_channels: VkVideoLiveWebSocketChannels?
}

struct VkVideoLiveCategory: Codable, Identifiable {
    let cover_url: String?
    let id: String
    let title: String
    let type: String
}

struct VkVideoLiveCounters: Decodable {
    let viewers: Int?
    let views: Int?
}

struct VkVideoLiveStream: Decodable {
    let category: VkVideoLiveCategory?
    let counters: VkVideoLiveCounters?
    let ended_at: Int64?
    let id: String
    let started_at: Int64?
    let status: String?
    let title: String?
}

struct VkVideoLiveChannelData: Decodable {
    let channel: VkVideoLiveChannel?
    let stream: VkVideoLiveStream?
}

private struct VkVideoLiveChannelResponse: Decodable {
    let data: VkVideoLiveChannelData?
}

struct VkVideoLiveCurrentUserChannel: Decodable {
    let url: String?
}

struct VkVideoLiveCurrentUser: Decodable {
    let avatar_url: String?
    let id: Int64?
    let is_streamer: Bool?
    let nick: String?
}

struct VkVideoLiveCurrentUserData: Decodable {
    let channel: VkVideoLiveCurrentUserChannel?
    let user: VkVideoLiveCurrentUser?
}

private struct VkVideoLiveCurrentUserResponse: Decodable {
    let data: VkVideoLiveCurrentUserData?
}

private struct VkVideoLiveCategorySearchData: Decodable {
    let categories: [VkVideoLiveCategory]?
}

private struct VkVideoLiveCategorySearchResponse: Decodable {
    let data: VkVideoLiveCategorySearchData?
}

private struct VkVideoLiveWebSocketTokenData: Decodable {
    let token: String?
}

private struct VkVideoLiveWebSocketTokenResponse: Decodable {
    let data: VkVideoLiveWebSocketTokenData?
}

struct VkVideoLiveChannelToken: Decodable {
    let channel: String?
    let token: String?
}

struct VkVideoLiveChatMemberUser: Decodable {
    let id: Int64?
    let nick: String?
    let nick_color: Int?
}

struct VkVideoLiveChatMemberData: Decodable {
    let user: VkVideoLiveChatMemberUser?
}

private struct VkVideoLiveChatMemberResponse: Decodable {
    let data: VkVideoLiveChatMemberData?
}

private struct VkVideoLiveWebSocketSubscriptionTokenData: Decodable {
    let channel_tokens: [VkVideoLiveChannelToken]?
}

private struct VkVideoLiveWebSocketSubscriptionTokenResponse: Decodable {
    let data: VkVideoLiveWebSocketSubscriptionTokenData?
}

struct VkVideoLiveChatModeGeneral: Codable {
    var is_caps_prohibited: Bool?
    var is_links_prohibited: Bool?
    var is_ru_en_numbers: Bool?
}

struct VkVideoLiveChatModeOnlySmiles: Codable {}

struct VkVideoLiveChatMode: Codable {
    var general: VkVideoLiveChatModeGeneral?
    var only_smiles: VkVideoLiveChatModeOnlySmiles?
}

struct VkVideoLiveChatSettings: Codable {
    var allow_access: String?
    var allow_access_after: Int64?
    var any_message_timeout: Int64?
    var follow_alert: Bool?
    var mode: VkVideoLiveChatMode?
    var same_message_timeout: Int64?
    var subscription_alert: Bool?
}

private struct VkVideoLiveChatSettingsData: Decodable {
    let chat_settings: VkVideoLiveChatSettings?
}

private struct VkVideoLiveChatSettingsResponse: Decodable {
    let data: VkVideoLiveChatSettingsData?
}

private struct VkVideoLiveChatSettingsEditRequest: Encodable {
    let chat_settings: VkVideoLiveChatSettings
}

private struct VkVideoLiveSendMessageText: Encodable {
    let content: String
}

private struct VkVideoLiveSendMessagePart: Encodable {
    let text: VkVideoLiveSendMessageText
}

private struct VkVideoLiveSendMessageRequest: Encodable {
    let parts: [VkVideoLiveSendMessagePart]
}

private struct VkVideoLiveStreamEditStream: Encodable {
    var category: VkVideoLiveCategory?
    var title: String?
}

private struct VkVideoLiveStreamEditRequest: Encodable {
    let stream: VkVideoLiveStreamEditStream
}

protocol VkVideoLiveApiDelegate: AnyObject {
    func vkVideoLiveApiUnauthorized()
}

class VkVideoLiveApi {
    private let accessToken: String
    weak var delegate: (any VkVideoLiveApiDelegate)?

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func getCurrentUser(onComplete: @escaping (VkVideoLiveCurrentUserData?) -> Void) {
        doGet(subPath: "current_user", parameters: []) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveCurrentUserResponse.self, from: data)
                onComplete(response?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func getChannel(channelUrl: String, onComplete: @escaping (VkVideoLiveChannelData?) -> Void) {
        doGet(subPath: "channel", parameters: [("channel_url", channelUrl)]) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveChannelResponse.self, from: data)
                onComplete(response?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func sendChatMessage(channelUrl: String,
                         streamId: String,
                         message: String,
                         onComplete: @escaping (OperationResult) -> Void)
    {
        let body = VkVideoLiveSendMessageRequest(parts: [.init(text: .init(content: message))])
        guard let body = try? JSONEncoder().encode(body) else {
            onComplete(.error)
            return
        }
        doPost(subPath: "chat/message/send",
               parameters: [("channel_url", channelUrl), ("stream_id", streamId)],
               body: body,
               onComplete: onComplete)
    }

    func editStream(channelUrl: String,
                    title: String?,
                    category: VkVideoLiveCategory?,
                    onComplete: @escaping (OperationResult) -> Void)
    {
        let body = VkVideoLiveStreamEditRequest(stream: .init(category: category, title: title))
        guard let body = try? JSONEncoder().encode(body) else {
            onComplete(.error)
            return
        }
        doPost(subPath: "channel/stream/edit",
               parameters: [("channel_url", channelUrl)],
               body: body,
               onComplete: onComplete)
    }

    func searchCategories(query: String,
                          type: String,
                          onComplete: @escaping ([VkVideoLiveCategory]?) -> Void)
    {
        doGet(subPath: "category/search",
              parameters: [("query", query), ("type", type), ("limit", "50")])
        {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveCategorySearchResponse.self, from: data)
                onComplete(response?.data?.categories)
            default:
                onComplete(nil)
            }
        }
    }

    func getChatMember(channelUrl: String,
                       userId: String,
                       onComplete: @escaping (VkVideoLiveChatMemberData?) -> Void)
    {
        doGet(subPath: "chat/member", parameters: [("channel_url", channelUrl), ("user_id", userId)]) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveChatMemberResponse.self, from: data)
                onComplete(response?.data)
            default:
                onComplete(nil)
            }
        }
    }

    func getChatSettings(channelUrl: String, onComplete: @escaping (VkVideoLiveChatSettings?) -> Void) {
        doGet(subPath: "chat/settings", parameters: [("channel_url", channelUrl)]) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveChatSettingsResponse.self, from: data)
                onComplete(response?.data?.chat_settings)
            default:
                onComplete(nil)
            }
        }
    }

    func editChatSettings(channelUrl: String,
                          settings: VkVideoLiveChatSettings,
                          onComplete: @escaping (OperationResult) -> Void)
    {
        let body = VkVideoLiveChatSettingsEditRequest(chat_settings: settings)
        guard let body = try? JSONEncoder().encode(body) else {
            onComplete(.error)
            return
        }
        doPost(subPath: "chat/settings/edit",
               parameters: [("channel_url", channelUrl)],
               body: body,
               onComplete: onComplete)
    }

    func getWebSocketSubscriptionTokens(
        channels: [String],
        onComplete: @escaping ([VkVideoLiveChannelToken]?) -> Void
    ) {
        doGet(subPath: "websocket/subscription_token",
              parameters: [("channels", channels.joined(separator: ","))])
        {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(
                    VkVideoLiveWebSocketSubscriptionTokenResponse.self,
                    from: data
                )
                onComplete(response?.data?.channel_tokens)
            default:
                onComplete(nil)
            }
        }
    }

    func getWebSocketToken(onComplete: @escaping (String?) -> Void) {
        doGet(subPath: "websocket/token", parameters: []) {
            switch $0 {
            case let .success(data):
                let response = try? JSONDecoder().decode(VkVideoLiveWebSocketTokenResponse.self, from: data)
                onComplete(response?.data?.token)
            default:
                onComplete(nil)
            }
        }
    }

    private func doGet(subPath: String,
                       parameters: [(String, String)],
                       onComplete: @escaping (OperationResult) -> Void)
    {
        guard let url = makeUrl(subPath: subPath, parameters: parameters) else {
            onComplete(.error)
            return
        }
        doRequest(createRequest(url: url, method: "GET"), onComplete)
    }

    private func doPost(subPath: String,
                        parameters: [(String, String)],
                        body: Data,
                        onComplete: @escaping (OperationResult) -> Void)
    {
        guard let url = makeUrl(subPath: subPath, parameters: parameters) else {
            onComplete(.error)
            return
        }
        var request = createRequest(url: url, method: "POST", json: true)
        request.httpBody = body
        doRequest(request, onComplete)
    }

    private func makeUrl(subPath: String, parameters: [(String, String)]) -> URL? {
        guard var urlComponents = URLComponents(string: "\(apiUrl)/v1/\(subPath)") else {
            return nil
        }
        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
        }
        return urlComponents.url
    }

    private func doRequest(_ request: URLRequest, _ onComplete: @escaping (OperationResult) -> Void) {
        httpRequest(request: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                if let data, let data = String(bytes: data, encoding: .utf8) {
                    logger.info("vk-video-live: api: Error response body: \(data)")
                }
                if response?.http?.isUnauthorized == true {
                    self.delegate?.vkVideoLiveApiUnauthorized()
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
        request.setAuthorization("Bearer \(accessToken)")
        if json {
            request.setContentType("application/json")
        }
        return request
    }
}
