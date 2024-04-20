import Foundation

protocol EventDispatcherConvertible: AnyObject {
    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func dispatch(event: Event)
    func dispatch(_ type: Event.Name, data: Any?)
}

open class Event {
    public struct Name: RawRepresentable, ExpressibleByStringLiteral {
        // swiftlint:disable:next nesting
        public typealias RawValue = String
        // swiftlint:disable:next nesting
        public typealias StringLiteralType = String

        public static let event: Name = "event"
        public static let ioError: Name = "ioError"
        public static let rtmpStatus: Name = "rtmpStatus"

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            rawValue = value
        }
    }

    public static func from(_ notification: Notification) -> Event {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let event: Event = userInfo["event"] as? Event
        else {
            return Event(type: .event)
        }
        return event
    }

    public fileprivate(set) var type: Name

    public fileprivate(set) var data: Any?

    public fileprivate(set) var target: AnyObject?

    public init(type: Name, data: Any? = nil) {
        self.type = type
        self.data = data
    }
}

open class EventDispatcher: EventDispatcherConvertible {
    private weak var target: AnyObject?

    public init() {}

    public init(target: AnyObject) {
        self.target = target
    }

    deinit {
        target = nil
    }

    public func addEventListener(
        _ type: Event.Name,
        selector: Selector,
        observer: AnyObject? = nil,
        useCapture: Bool = false
    ) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self, selector: selector,
            name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"), object: target ?? self
        )
    }

    public func removeEventListener(
        _ type: Event.Name,
        selector _: Selector,
        observer: AnyObject? = nil,
        useCapture: Bool = false
    ) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self, name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"),
            object: target ?? self
        )
    }

    open func dispatch(event: Event) {
        event.target = target ?? self
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "\(event.type.rawValue)/false"), object: target ?? self,
            userInfo: ["event": event]
        )
        event.target = nil
    }

    public func dispatch(_ type: Event.Name, data: Any?) {
        dispatch(event: Event(type: type, data: data))
    }
}
