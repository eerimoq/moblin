import Foundation

struct YouTubeApiLiveBroadcast: Codable {
    let id: String
}

struct YouTubeApiLiveStreamIngestInfo: Codable {
    // periphery: ignore
    let streamName: String
    // periphery: ignore
    let ingestionAddress: String
}

struct YouTubeApiLiveStreamCdn: Codable {
    // periphery: ignore
    let ingestionInfo: YouTubeApiLiveStreamIngestInfo
}

struct YouTubeApiLiveStream: Codable {
    let id: String
    // periphery: ignore
    let cdn: YouTubeApiLiveStreamCdn
}

struct YouTubeApiLiveStreamsListResponse: Codable {
    let items: [YouTubeApiLiveStream]
}

private func serialize(_ value: Any) -> Data {
    return (try? JSONSerialization.data(withJSONObject: value))!
}

enum YouTubeApiLiveBroadcasePrivacy: String {
    case `public`
    case `private`
    case unlisted
}

struct YouTubeApiListVideoStreamingDetails: Codable {
    let concurrentViewers: String
}

struct YouTubeApiListVideo: Codable {
    let liveStreamingDetails: YouTubeApiListVideoStreamingDetails
}

struct YouTubeApiListVideosResponse: Codable {
    let items: [YouTubeApiListVideo]
}

class YouTubeApi {
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func listVideos(
        videoId: String,
        onCompleted: @escaping (NetworkResponse<YouTubeApiListVideosResponse>) -> Void
    ) {
        let subPath = makeUrl("videos", [
            ("part", "liveStreamingDetails"),
            ("id", videoId),
        ])
        doGet(subPath: subPath) {
            switch $0 {
            case let .success(data):
                if let response = try? JSONDecoder().decode(YouTubeApiListVideosResponse.self, from: data) {
                    onCompleted(.success(response))
                } else {
                    onCompleted(.error)
                }
            case .authError:
                onCompleted(.authError)
            case .error:
                onCompleted(.error)
            }
        }
    }

    // periphery: ignore
    func listLiveBroadcasts() {
        let subPath = makeUrl("liveBroadcasts", [
            ("part", "snippet,contentDetails,status"),
            ("mine", "true"),
            ("broadcastType", "all"),
        ])
        doGet(subPath: subPath) { _ in }
    }

    func insertLiveBroadcast(title: String,
                             privacy: YouTubeApiLiveBroadcasePrivacy,
                             onCompleted: @escaping (NetworkResponse<YouTubeApiLiveBroadcast>) -> Void)
    {
        let subPath = makeUrl("liveBroadcasts", [("part", "snippet,contentDetails,status")])
        let body: [String: Any] = [
            "snippet": [
                "title": title,
                "scheduledStartTime": Date().ISO8601Format(),
            ],
            "contentDetails": [
                "enableAutoStart": true,
                "enableAutoStop": true,
            ],
            "status": [
                "privacyStatus": privacy.rawValue,
                "selfDeclaredMadeForKids": false,
            ],
        ]
        doPost(subPath: subPath, body: serialize(body)) {
            switch $0 {
            case let .success(data):
                if let response = try? JSONDecoder().decode(YouTubeApiLiveBroadcast.self, from: data) {
                    onCompleted(.success(response))
                } else {
                    onCompleted(.error)
                }
            case .authError:
                onCompleted(.authError)
            case .error:
                onCompleted(.error)
            }
        }
    }

    func bindLiveBroadcast(boardcastId: String, streamId: String, onCompleted: @escaping (Bool) -> Void) {
        let subPath = makeUrl("liveBroadcasts/bind", [
            ("id", boardcastId),
            ("streamId", streamId),
            ("part", "snippet,contentDetails,status"),
        ])
        doPost(subPath: subPath, body: Data()) {
            switch $0 {
            case .success:
                onCompleted(true)
            default:
                onCompleted(false)
            }
        }
    }

    func listLiveStreams(onCompleted: @escaping (NetworkResponse<YouTubeApiLiveStreamsListResponse>)
        -> Void)
    {
        let subPath = makeUrl("liveStreams", [
            ("part", "snippet,cdn,contentDetails,status"),
            ("mine", "true"),
        ])
        doGet(subPath: subPath) {
            switch $0 {
            case let .success(data):
                if let response = try? JSONDecoder().decode(
                    YouTubeApiLiveStreamsListResponse.self,
                    from: data
                ) {
                    onCompleted(.success(response))
                } else {
                    onCompleted(.error)
                }
            case .authError:
                onCompleted(.authError)
            case .error:
                onCompleted(.error)
            }
        }
    }

    // periphery: ignore
    func insertLiveStream(onCompleted: @escaping (YouTubeApiLiveStream?) -> Void) {
        let subPath = makeUrl("liveStreams", [("part", "snippet,cdn,contentDetails,status")])
        let body: [String: Any] = [
            "snippet": [
                "title": "Test broadcast",
            ],
            "cdn": [
                "frameRate": "variable",
                "ingestionType": "rtmp",
                "resolution": "variable",
            ],
        ]
        doPost(subPath: subPath, body: serialize(body)) {
            switch $0 {
            case let .success(data):
                onCompleted(try? JSONDecoder().decode(YouTubeApiLiveStream.self, from: data))
            default:
                break
            }
        }
    }

    private func doGet(subPath: String, onComplete: @escaping ((OperationResult) -> Void)) {
        guard let url = URL(string: "https://youtube.googleapis.com/youtube/v3/\(subPath)") else {
            return
        }
        let request = createGetRequest(url: url)
        doRequest(request, onComplete)
    }

    private func doPost(subPath: String, body: Data, onComplete: @escaping (OperationResult) -> Void) {
        guard let url = URL(string: "https://youtube.googleapis.com/youtube/v3/\(subPath)") else {
            return
        }
        var request = createPostRequest(url: url)
        request.httpBody = body
        doRequest(request, onComplete)
    }

    private func doRequest(_ request: URLRequest, _ onComplete: @escaping (OperationResult) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let data, response?.http?.isSuccessful == true else {
                    if let data, let data = String(bytes: data, encoding: .utf8) {
                        logger.info("youtube-api: Error response body: \(data)")
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

    private func createGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setAuthorization("Bearer \(accessToken)")
        return request
    }

    private func createPostRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setAuthorization("Bearer \(accessToken)")
        request.setContentType("application/json")
        return request
    }
}
