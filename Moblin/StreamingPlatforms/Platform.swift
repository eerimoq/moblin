import Foundation

enum Platform: Codable, CaseIterable {
    case soop
    case kick
    case openStreamingPlatform
    case twitch
    case youTube

    func name() -> String {
        switch self {
        case .soop:
            return String(localized: "SOOP")
        case .kick:
            return String(localized: "Kick")
        case .openStreamingPlatform:
            return String(localized: "Open Streaming Platform")
        case .twitch:
            return String(localized: "Twitch")
        case .youTube:
            return String(localized: "YouTube")
        }
    }

    func imageName() -> String {
        switch self {
        case .soop:
            return "SoopLogo"
        case .kick:
            return "KickLogo"
        case .openStreamingPlatform:
            return "OpenStreamingPlatform"
        case .twitch:
            return "TwitchLogo"
        case .youTube:
            return "YouTubeLogo"
        }
    }
}
