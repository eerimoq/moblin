import Foundation

enum Platform: Codable {
    case afreecaTv
    case kick
    case openStreamingPlatform
    case twitch
    case youTube

    func imageName() -> String? {
        switch self {
        case .afreecaTv:
            return nil
        case .kick:
            return "KickLogo"
        case .openStreamingPlatform:
            return nil
        case .twitch:
            return "TwitchLogo"
        case .youTube:
            return "YouTubeLogo"
        }
    }
}
