import Foundation

class RtmpEvent {
    struct Name: RawRepresentable, ExpressibleByStringLiteral {
        static let rtmpStatus: Name = "rtmpStatus"
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(stringLiteral value: String) {
            rawValue = value
        }
    }

    static func from(_ notification: Notification) -> RtmpEvent? {
        return notification.userInfo?["event"] as? RtmpEvent
    }

    let type: Name
    let data: Any?

    init(type: Name, data: Any? = nil) {
        self.type = type
        self.data = data
    }
}
