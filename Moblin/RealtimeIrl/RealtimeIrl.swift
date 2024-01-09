import CoreLocation
import Foundation

class RealtimeIrl {
    private let pushKey: String

    init(pushKey: String) {
        self.pushKey = pushKey
    }

    func update(location: CLLocation) {
        var request = URLRequest(url: URL(string: "https://rtirl.com/api/push?key=\(pushKey)")!)
        request.httpMethod = "POST"
        request.httpBody = """
        {
          \"latitude\":\(location.coordinate.latitude),
          \"longitude\":\(location.coordinate.longitude)
        }
        """
        .data(using: String.Encoding.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }
}
