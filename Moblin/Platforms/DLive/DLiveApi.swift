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

func getDLiveUserInfo(
    displayName: String,
    completion: @escaping (Result<DLiveUserInfo, DLiveApiError>) -> Void
) {
    guard let url = URL(string: "https://graphigo.prd.dlive.tv/") else {
        completion(.failure(.invalidResponse))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let query = """
    query UserByDisplayName($displayname: String!) {
      userByDisplayName(displayname: $displayname) {
        id
        username
        displayname
      }
    }
    """
    let payload: [String: Any] = [
        "query": query,
        "variables": [
            "displayname": displayName,
        ],
    ]
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        completion(.failure(.invalidResponse))
        return
    }
    request.httpBody = jsonData
    URLSession.shared.dataTask(with: request) { data, _, error in
        if error != nil {
            completion(.failure(.networkError))
            return
        }
        guard let data = data else {
            completion(.failure(.invalidResponse))
            return
        }
        do {
            let userResponse = try JSONDecoder().decode(DLiveUserResponse.self, from: data)
            if let userInfo = userResponse.data.userByDisplayName {
                completion(.success(userInfo))
            } else {
                completion(.failure(.userNotFound))
            }
        } catch {
            logger.debug("dlive: Failed to decode user info: \(error)")
            completion(.failure(.invalidResponse))
        }
    }.resume()
}
