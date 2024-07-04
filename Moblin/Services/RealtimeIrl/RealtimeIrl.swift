import CoreLocation
import Foundation

class RealtimeIrl {
    private let pushKey: String
    private var updateCount = 0

    init(pushKey: String) {
        self.pushKey = pushKey
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
        var request = URLRequest(url: URL(string: "https://rtirl.com/api/push?key=\(pushKey)")!)
        request.httpMethod = "POST"
        request.httpBody = Data("""
        {
          \"latitude\":\(location.coordinate.latitude),
          \"longitude\":\(location.coordinate.longitude),
          \"speed\":\(location.speed),
          \"timestamp\":\(location.timestamp.timeIntervalSince1970)
        }
        """.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }

    func stop() {
        updateCount = 0
        var request = URLRequest(url: URL(string: "https://rtirl.com/api/stop?key=\(pushKey)")!)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }
}
