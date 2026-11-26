import Foundation

struct DoinkApiRegion: Decodable {
    let region: String
    let label: String
    let srtlaUrl: String
    let pingUrl: String?
}

func doinkPing(url: URL, attempts: Int = 2, best: Int? = nil, onComplete: @escaping (Int?) -> Void) {
    guard attempts > 0 else {
        onComplete(best)
        return
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let start = Date()
    httpRequest(request: request) { _, response, _ in
        var best = best
        if response?.http != nil {
            best = min(best ?? .max, Int(Date().timeIntervalSince(start) * 1000))
        }
        doinkPing(url: url, attempts: attempts - 1, best: best, onComplete: onComplete)
    }
}

struct DoinkApiIngest: Decodable {
    let handle: String
    let srtlaUrl: String
    let regions: [DoinkApiRegion]
}

private struct DoinkApiError: Decodable {
    let error: String
}

enum DoinkApiResult<T> {
    case success(T)
    case authError
    case error(String?)
}

func doinkStreamKey(url: String) -> String? {
    guard let components = URLComponents(string: url),
          components.host?.hasSuffix("ingest.doink.tv") == true,
          let streamId = components.queryItems?.first(where: { $0.name == "streamid" })?.value,
          streamId.hasPrefix("publish:")
    else {
        return nil
    }
    return String(streamId.dropFirst("publish:".count))
}

class DoinkApi {
    private let credential: String

    init(accessTokenOrStreamKey: String) {
        credential = accessTokenOrStreamKey
    }

    func getIngest(onComplete: @escaping (DoinkApiResult<DoinkApiIngest>) -> Void) {
        doRequest(onComplete)
    }

    func doRequest<T: Decodable>(method: String = "GET",
                                 subPath: String = "",
                                 body: [String: Any]? = nil,
                                 _ onComplete: @escaping (DoinkApiResult<T>) -> Void)
    {
        var request = URLRequest(url: URL(string: "https://doink.tv/api/app/stream\(subPath)")!)
        request.httpMethod = method
        request.setAuthorization("Bearer \(credential)")
        if let body {
            request.setContentType("application/json")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        httpRequest(request: request) { data, response, _ in
            if response?.http?.isSuccessful == true,
               let value = try? JSONDecoder().decode(T.self, from: data ?? Data())
            {
                onComplete(.success(value))
            } else if response?.http?.isUnauthorized == true {
                onComplete(.authError)
            } else {
                let message = try? JSONDecoder().decode(DoinkApiError.self, from: data ?? Data())
                onComplete(.error(message?.error))
            }
        }
    }
}
