import Foundation

enum Platform: Codable, CaseIterable {
    case soop
    case kick
    case openStreamingPlatform
    case twitch
    case vkVideoLive
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
        case .vkVideoLive:
            String(localized: "VK Video Live")
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
        case .vkVideoLive:
            "VkVideoLiveLogo"
        case .youTube:
            "YouTubeLogo"
        }
    }
}
