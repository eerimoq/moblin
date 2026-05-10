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
            String(localized: "SOOP")
        case .kick:
            String(localized: "Kick")
        case .openStreamingPlatform:
            String(localized: "Open Streaming Platform")
        case .twitch:
            String(localized: "Twitch")
        case .youTube:
            String(localized: "YouTube")
        }
    }

    func imageName() -> String {
        switch self {
        case .soop:
            "SoopLogo"
        case .kick:
            "KickLogo"
        case .openStreamingPlatform:
            "OpenStreamingPlatform"
        case .twitch:
            "TwitchLogo"
        case .youTube:
            "YouTubeLogo"
        }
    }
}
