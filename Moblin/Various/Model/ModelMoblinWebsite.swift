import Foundation

private struct MoblinWebsiteChannel: Encodable {
    let platform: String
    let channel: String
}

private struct MoblinWebsiteWentLive: Encodable {
    let channels: [MoblinWebsiteChannel]
}

extension Model {
    func sendWentLiveToMoblinWebsite() {
        guard stream.goLiveNotificationMoblinWebsite else {
            return
        }
        var channels: [MoblinWebsiteChannel] = []
        let twitchChannelName = stream.twitchChannelName.trim()
        if stream.twitchLoggedIn, !twitchChannelName.isEmpty {
            channels.append(.init(platform: "twitch", channel: twitchChannelName))
        }
        let youTubeHandle = String(stream.youTubeHandle.trim().trimmingPrefix("@"))
        if stream.isYouTubeAuthorized(), !youTubeHandle.isEmpty {
            channels.append(.init(platform: "youtube", channel: youTubeHandle))
        }
        let kickChannelName = stream.kickChannelName.trim()
        if stream.kickLoggedIn, !kickChannelName.isEmpty {
            channels.append(.init(platform: "kick", channel: kickChannelName))
        }
        guard !channels.isEmpty,
              let body = try? JSONEncoder().encode(MoblinWebsiteWentLive(channels: channels))
        else {
            return
        }
        var request = URLRequest(url: URL(string: "https://api.moblin.app/streamers/live")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        httpRequest(request: request) { _, response, error in
            guard error == nil, response?.http?.isSuccessful == true else {
                logger.info("moblin-website: Failed to send went live")
                return
            }
        }
    }
}
