import Foundation

protocol RtmpEventDispatcherConvertible: AnyObject {
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
    private weak var target: AnyObject?

    init() {}

    init(target: AnyObject) {
        self.target = target
    }

    func addEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self,
            selector: selector,
            name: Notification.Name(rawValue: type.rawValue),
            object: target ?? self
        )
    }

    func removeEventListener(_ type: RtmpEvent.Name, selector _: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self,
            name: Notification.Name(rawValue: type.rawValue),
            object: target ?? self
        )
    }

    func dispatch(event: RtmpEvent) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: event.type.rawValue),
            object: target ?? self,
            userInfo: ["event": event]
        )
    }

    func dispatch(_ type: RtmpEvent.Name, data: Any?) {
        dispatch(event: RtmpEvent(type: type, data: data))
    }
}
