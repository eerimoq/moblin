import Foundation

struct DoinkApiTarget: Decodable {
    let target_id: String
    let name: String?
    let platform: String
    let rtmp_url: String
    let enabled: Int
}

struct DoinkApiStream: Decodable {
    var title: String
    var fallbackEnabled: Bool
    var fallbackMinutes: Int
    let targets: [DoinkApiTarget]
    let targetLimit: Int
}

struct DoinkApiOk: Decodable {}

struct DoinkApiStreamKey: Decodable {
    let streamKey: String
}

extension DoinkApi {
    func getStream(onComplete: @escaping (DoinkApiResult<DoinkApiStream>) -> Void) {
        doRequest(onComplete)
    }

    func updateStream(stream: DoinkApiStream, onComplete: @escaping (DoinkApiResult<DoinkApiOk>) -> Void) {
        doRequest(method: "PATCH", body: [
            "title": stream.title,
            "fallbackEnabled": stream.fallbackEnabled,
            "fallbackMinutes": stream.fallbackMinutes,
        ], onComplete)
    }

    func rotateStreamKey(onComplete: @escaping (DoinkApiResult<DoinkApiStreamKey>) -> Void) {
        doRequest(method: "POST", subPath: "/rotate-key", onComplete)
    }

    func endStream(onComplete: @escaping (DoinkApiResult<DoinkApiOk>) -> Void) {
        doRequest(method: "POST", subPath: "/end", onComplete)
    }

    func addTarget(name: String,
                   platform: String,
                   url: String,
                   key: String,
                   onComplete: @escaping (DoinkApiResult<DoinkApiOk>) -> Void)
    {
        let body = ["name": name, "platform": platform, "url": url, "key": key]
        doRequest(method: "POST", subPath: "/targets", body: body, onComplete)
    }

    func setTargetEnabled(targetId: String,
                          enabled: Bool,
                          onComplete: @escaping (DoinkApiResult<DoinkApiOk>) -> Void)
    {
        doRequest(method: "PATCH", subPath: "/targets/\(targetId)", body: ["enabled": enabled], onComplete)
    }

    func deleteTarget(targetId: String, onComplete: @escaping (DoinkApiResult<DoinkApiOk>) -> Void) {
        doRequest(method: "DELETE", subPath: "/targets/\(targetId)", onComplete)
    }
}
