import Foundation

private protocol RtmpEventDispatcherConvertible: AnyObject {
    func addEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject?)
    func removeEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject?)
}

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

class RtmpEventDispatcher: RtmpEventDispatcherConvertible {
    init() {}

    func addEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.addObserver(
            observer ?? self,
            selector: selector,
            name: Notification.Name(rawValue: type.rawValue),
            object: self
        )
    }

    func removeEventListener(_ type: RtmpEvent.Name, selector _: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(
            observer ?? self,
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
