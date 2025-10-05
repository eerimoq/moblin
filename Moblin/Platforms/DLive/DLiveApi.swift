import Foundation

struct DLiveTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let token_type: String
}

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
    case invalidCredentials
    case networkError
    case invalidResponse
    case userNotFound
}

func getDLiveAccessToken(
    appId: String,
    appSecret: String,
    completion: @escaping (Result<DLiveTokenResponse, DLiveApiError>) -> Void
) {
    guard let url = URL(string: "https://dlive.tv/o/token") else {
        completion(.failure(.invalidResponse))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let credentials = "\(appId):\(appSecret)"
    guard let credentialsData = credentials.data(using: .utf8) else {
        completion(.failure(.invalidCredentials))
        return
    }
    let base64Credentials = credentialsData.base64EncodedString()
    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
    let bodyString = "grant_type=client_credentials"
    request.httpBody = bodyString.data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    URLSession.shared.dataTask(with: request) { data, response, error in
        if error != nil {
            completion(.failure(.networkError))
            return
        }

        guard let data = data,
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            completion(.failure(.invalidResponse))
            return
        }

        do {
            let tokenResponse = try JSONDecoder().decode(DLiveTokenResponse.self, from: data)
            completion(.success(tokenResponse))
        } catch {
            completion(.failure(.invalidResponse))
        }
    }.resume()
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
