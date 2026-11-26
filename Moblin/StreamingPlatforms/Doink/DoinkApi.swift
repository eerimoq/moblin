import Foundation

struct DoinkApiRegion: Decodable {
    let region: String
    let label: String
    let srtlaUrl: String
}

struct DoinkApiIngest: Decodable {
    let handle: String
    let srtlaUrl: String
    let regions: [DoinkApiRegion]
}

enum DoinkApiResult<T> {
    case success(T)
    case authError
    case error
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

    func doRequest<T: Decodable>(_ onComplete: @escaping (DoinkApiResult<T>) -> Void) {
        var request = URLRequest(url: URL(string: "https://doink.tv/api/app/stream")!)
        request.setAuthorization("Bearer \(credential)")
        httpRequest(request: request) { data, response, _ in
            if response?.http?.isSuccessful == true,
               let value = try? JSONDecoder().decode(T.self, from: data ?? Data())
            {
                onComplete(.success(value))
            } else if response?.http?.isUnauthorized == true {
                onComplete(.authError)
            } else {
                onComplete(.error)
            }
        }
    }
}
