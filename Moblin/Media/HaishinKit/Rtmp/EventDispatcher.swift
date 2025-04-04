import Foundation

protocol EventDispatcherConvertible: AnyObject {
    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?)
    func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?)
    func dispatch(_ type: Event.Name, data: Any?)
}

class Event {
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

    static func from(_ notification: Notification) -> Event? {
        return notification.userInfo?["event"] as? Event
    }

    let type: Name
    let data: Any?

    init(type: Name, data: Any? = nil) {
        self.type = type
        self.data = data
    }
}

class RtmpEventDispatcher: EventDispatcherConvertible {
    private weak var target: AnyObject?

    init() {}

    init(target: AnyObject) {
        self.target = target
    }

    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self,
            selector: selector,
            name: Notification.Name(rawValue: type.rawValue),
            object: target ?? self
        )
    }

    func removeEventListener(_ type: Event.Name, selector _: Selector, observer: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self,
            name: Notification.Name(rawValue: type.rawValue),
            object: target ?? self
        )
    }

    func dispatch(event: Event) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: event.type.rawValue),
            object: target ?? self,
            userInfo: ["event": event]
        )
    }

    func dispatch(_ type: Event.Name, data: Any?) {
        dispatch(event: Event(type: type, data: data))
    }
}
