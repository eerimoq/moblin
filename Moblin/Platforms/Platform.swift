import Foundation

enum Platform: Codable {
    case soop
    case kick
    case openStreamingPlatform
    case twitch
    case youTube
    case dlive

    func imageName() -> String? {
        switch self {
        case .soop:
            return "SoopLogo"
        case .dlive:
            return "DLiveLogo"
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
