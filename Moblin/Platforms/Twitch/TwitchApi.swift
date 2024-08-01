import Foundation

struct TwitchApiUser: Codable {
    let id: String
    let login: String
}

struct TwitchApiUsers: Codable {
    let data: [TwitchApiUser]
}

class TwitchApi {
    private let clientId: String
    private let accessToken: String

    init(accessToken: String) {
        clientId = twitchMoblinAppClientId
        self.accessToken = accessToken
    }

    private func createGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "client-id")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        return request
    }

    func getUsers(onComplete: @escaping ((TwitchApiUsers?, Bool) -> Void)) {
        guard let url = URL(string: "https://api.twitch.tv/helix/users") else {
            return
        }
        let request = createGetRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil, response?.http?.isUnauthorized == true)
                return
            }
            onComplete(try? JSONDecoder().decode(TwitchApiUsers.self, from: data), false)
        }
        .resume()
    }

    func getUserInfo(onComplete: @escaping ((TwitchApiUser?, Bool) -> Void)) {
        getUsers(onComplete: { users, unauthorized in
            onComplete(users?.data.first, unauthorized)
        })
    }
}
