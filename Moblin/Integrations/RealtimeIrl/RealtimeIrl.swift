import CoreLocation
import Foundation

class RealtimeIrl {
    private let pushUrl: URL
    private let stopUrl: URL
    private var updateCount = 0

    init?(baseUrl: String, pushKey: String) {
        guard let url = URL(string: "\(baseUrl)/push?key=\(pushKey)") else {
            return nil
        }
        pushUrl = url
        guard let url = URL(string: "\(baseUrl)/stop?key=\(pushKey)") else {
            return nil
        }
        stopUrl = url
    }

    func status() -> String {
        if updateCount > 0 {
            return " (\(updateCount))"
        } else {
            return ""
        }
    }

    func update(location: CLLocation) {
        updateCount += 1
        var request = URLRequest(url: pushUrl)
        request.httpMethod = "POST"
        request.httpBody = """
        {
          \"latitude\":\(location.coordinate.latitude),
          \"longitude\":\(location.coordinate.longitude),
          \"speed\":\(location.speed),
          \"altitude\":\(location.altitude),
          \"timestamp\":\(location.timestamp.timeIntervalSince1970)
        }
        """.utf8Data
        request.setContentType("application/json")
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }

    func stop() {
        updateCount = 0
        var request = URLRequest(url: stopUrl)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }
}
