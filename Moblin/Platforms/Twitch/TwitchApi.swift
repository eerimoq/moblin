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

class TwitchApi {
    private let clientId: String
    private let accessToken: String

    init(accessToken: String) {
        clientId = twitchMoblinAppClientId
        self.accessToken = accessToken
    }

    func getUsers(onComplete: @escaping (TwitchApiUsers?, Bool) -> Void) {
        doGet(subPath: "users", onComplete: { data, unauthorized in
            onComplete(try? JSONDecoder().decode(TwitchApiUsers.self, from: data ?? Data()), unauthorized)
        })
    }

    func getUserInfo(onComplete: @escaping (TwitchApiUser?, Bool) -> Void) {
        getUsers(onComplete: { users, unauthorized in
            onComplete(users?.data.first, unauthorized)
        })
    }

    func createEventSubSubscription(body: String, onComplete: @escaping (Bool, Bool) -> Void) {
        doPost(subPath: "eventsub/subscriptions", body: body.utf8Data, onComplete: { data, unauthorized in
            onComplete(data != nil, unauthorized)
        })
    }

    // periphery:ignore
    func getEventSubSubscriptions(onComplete: @escaping (Bool, Bool) -> Void) {
        doGet(subPath: "eventsub/subscriptions", onComplete: { data, unauthorized in
            onComplete(data != nil, unauthorized)
        })
    }

    func getStreamKey(userId: String, onComplete: @escaping (String?, Bool) -> Void) {
        doGet(subPath: "streams/key?broadcaster_id=\(userId)", onComplete: { data, unauthorized in
            let response = try? JSONDecoder().decode(TwitchApiStreamKey.self, from: data ?? Data())
            onComplete(response?.data.first?.stream_key, unauthorized)
        })
    }

    private func doGet(subPath: String, onComplete: @escaping ((Data?, Bool) -> Void)) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        let request = createGetRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil, response?.http?.isUnauthorized == true)
                return
            }
            onComplete(data, false)
        }
        .resume()
    }

    private func doPost(subPath: String, body: Data, onComplete: @escaping (Data?, Bool) -> Void) {
        guard let url = URL(string: "https://api.twitch.tv/helix/\(subPath)") else {
            return
        }
        var request = createPostRequest(url: url)
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil, response?.http?.isUnauthorized == true)
                return
            }
            onComplete(data, false)
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
