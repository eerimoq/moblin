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

class RtmpEventDispatcher {
    func addEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject) {
        NotificationCenter.default.addObserver(
            observer,
            selector: selector,
            name: Notification.Name(rawValue: type.rawValue),
            object: self
        )
    }

    func removeEventListener(_ type: RtmpEvent.Name, selector _: Selector, observer: AnyObject) {
        NotificationCenter.default.removeObserver(
            observer,
            name: Notification.Name(rawValue: type.rawValue),
            object: self
        )
    }

    func post(event: RtmpEvent) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: event.type.rawValue),
            object: self,
            userInfo: ["event": event]
        )
    }
}
