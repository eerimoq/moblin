import ActivityKit
import Foundation

#if !targetEnvironment(macCatalyst)

struct LiveActionFunction: Codable, Hashable {
    let image: String
    let text: String
}

struct LiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var functions: [LiveActionFunction]
        var showEllipsis: Bool
    }
}

#endif
