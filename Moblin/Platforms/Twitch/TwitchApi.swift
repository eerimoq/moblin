import Foundation

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

protocol TwitchApiDelegate: AnyObject {
    func twitchApiUnauthorized()
}

class TwitchApi {
    private let clientId: String
    private let accessToken: String
    weak var delegate: (any TwitchApiDelegate)?

    init(accessToken: String) {
        clientId = twitchMoblinAppClientId
        self.accessToken = accessToken
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

    // periphery:ignore
    func getEventSubSubscriptions(onComplete: @escaping (Bool) -> Void) {
        doGet(subPath: "eventsub/subscriptions", onComplete: { data in
            onComplete(data != nil)
        })
    }

    func getStreamKey(userId: String, onComplete: @escaping (String?) -> Void) {
        doGet(subPath: "streams/key?broadcaster_id=\(userId)", onComplete: { data in
            let response = try? JSONDecoder().decode(TwitchApiStreamKey.self, from: data ?? Data())
            onComplete(response?.data.first?.stream_key)
        })
    }

    private func doGet(subPath: String, onComplete: @escaping ((Data?) -> Void)) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        let request = createGetRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                if response?.http?.isUnauthorized == true {
                    self.delegate?.twitchApiUnauthorized()
                }
                onComplete(nil)
                return
            }
            onComplete(data)
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
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                if response?.http?.isUnauthorized == true {
                    self.delegate?.twitchApiUnauthorized()
                }
                onComplete(nil)
                return
            }
            onComplete(data)
        }
        .resume()
    }

    private func createGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        return request
    }

    private func createPostRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }
}
