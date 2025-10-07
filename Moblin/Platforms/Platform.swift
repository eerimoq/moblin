import Foundation

enum Platform: Codable {
    case afreecaTv
    case kick
    case openStreamingPlatform
    case twitch
    case youTube
    case dlive

    func imageName() -> String? {
        switch self {
        case .afreecaTv:
            return nil
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
