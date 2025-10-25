import Foundation

struct DLiveUserInfo: Codable {
    let id: String
    let username: String
    let displayname: String
}

struct DLiveUserData: Codable {
    let userByDisplayName: DLiveUserInfo?
}

struct DLiveUserResponse: Codable {
    let data: DLiveUserData
}

enum DLiveApiError: Error {
    case networkError
    case invalidResponse
    case userNotFound
}

private let userInfoQuery = """
query UserByDisplayName($displayname: String!) {
  userByDisplayName(displayname: $displayname) {
    id
    username
    displayname
  }
}
"""

private let baseUrl = URL(string: "https://graphigo.prd.dlive.tv/")!

func getDLiveUserInfo(displayName: String, completion: @escaping (DLiveUserInfo?) -> Void) {
    var request = URLRequest(url: baseUrl)
    request.httpMethod = "POST"
    request.setContentType("application/json")
    let payload: [String: Any] = [
        "query": userInfoQuery,
        "variables": [
            "displayname": displayName,
        ],
    ]
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(nil)
        return
    }
    request.httpBody = jsonData
    URLSession.shared.dataTask(with: request) { data, _, error in
        guard error == nil, let data else {
            completion(nil)
            return
        }
        do {
            let userResponse = try JSONDecoder().decode(DLiveUserResponse.self, from: data)
            if let userInfo = userResponse.data.userByDisplayName {
                completion(userInfo)
            } else {
                completion(nil)
            }
        } catch {
            logger.debug("dlive: Failed to decode user info: \(error)")
            completion(nil)
        }
    }.resume()
}
