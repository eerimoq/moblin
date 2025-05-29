import CoreImage
import Foundation
import SwiftUI

extension Model {
    func isTwitchEventSubConfigured() -> Bool {
        return isTwitchAccessTokenConfigured()
    }

    func isTwitchEventsConnected() -> Bool {
        return twitchEventSub?.isConnected() ?? false
    }

    func isTwitchViewersConfigured() -> Bool {
        return stream.twitchChannelId != "" && isTwitchAccessTokenConfigured()
    }

    func isTwitchChatConfigured() -> Bool {
        return database.chat.enabled && stream.twitchChannelName != ""
    }

    func isTwitchAccessTokenConfigured() -> Bool {
        return stream.twitchAccessToken != ""
    }

    func isTwitchChatConnected() -> Bool {
        return twitchChat?.isConnected() ?? false
    }

    func hasTwitchChatEmotes() -> Bool {
        return twitchChat?.hasEmotes() ?? false
    }

    func reloadTwitchChat() {
        twitchChat.stop()
        setTextToSpeechStreamerMentions()
        if isTwitchChatConfigured(), !isChatRemoteControl() {
            twitchChat.start(
                channelName: stream.twitchChannelName,
                channelId: stream.twitchChannelId,
                settings: stream.chat,
                accessToken: stream.twitchAccessToken,
                httpProxy: httpProxy(),
                urlSession: urlSession
            )
        }
    }

    func twitchChannelNameUpdated() {
        reloadTwitchEventSub()
        reloadTwitchChat()
        resetChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchEventSub()
        reloadTwitchChat()
        resetChat()
    }

    func reloadTwitchEventSub() {
        twitchEventSub?.stop()
        twitchEventSub = nil
        if isTwitchEventSubConfigured() {
            twitchEventSub = TwitchEventSub(
                remoteControl: useRemoteControlForChatAndEvents,
                userId: stream.twitchChannelId,
                accessToken: stream.twitchAccessToken,
                httpProxy: httpProxy(),
                urlSession: urlSession,
                delegate: self
            )
            twitchEventSub!.start()
        }
    }

    func fetchTwitchRewards() {
        TwitchApi(stream.twitchAccessToken, urlSession)
            .getChannelPointsCustomRewards(broadcasterId: stream.twitchChannelId) { rewards in
                guard let rewards else {
                    logger.info("Failed to get Twitch rewards")
                    return
                }
                logger.info("Twitch rewards: \(rewards)")
                self.stream.twitchRewards = rewards.data.map {
                    let reward = SettingsStreamTwitchReward()
                    reward.rewardId = $0.id
                    reward.title = $0.title
                    return reward
                }
            }
    }

    func makeNotLoggedInToTwitchToast() {
        makeErrorToast(
            title: String(localized: "Not logged in to Twitch"),
            subTitle: String(localized: "Please login again")
        )
    }

    func getTwitchChannelInformation(
        stream: SettingsStream,
        onComplete: @escaping (TwitchApiChannelInformationData) -> Void
    ) {
        guard stream.twitchLoggedIn else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken, urlSession)
            .getChannelInformation(broadcasterId: stream.twitchChannelId) { channelInformation in
                guard let channelInformation else {
                    return
                }
                onComplete(channelInformation)
            }
    }

    func setTwitchStreamTitle(stream: SettingsStream, title: String) {
        guard stream.twitchLoggedIn else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken, urlSession)
            .modifyChannelInformation(broadcasterId: stream.twitchChannelId, category: nil,
                                      title: title)
            { ok in
                if !ok {
                    self.makeErrorToast(title: "Failed to set stream title")
                }
            }
    }

    func twitchLogin(stream: SettingsStream, onComplete: (() -> Void)? = nil) {
        twitchAuthOnComplete = { accessToken in
            storeTwitchAccessTokenInKeychain(streamId: stream.id, accessToken: accessToken)
            stream.twitchLoggedIn = true
            stream.twitchAccessToken = accessToken
            self.showTwitchAuth = false
            self.wizardShowTwitchAuth = false
            TwitchApi(accessToken, self.urlSession).getUserInfo { info in
                guard let info else {
                    return
                }
                stream.twitchChannelName = info.login
                stream.twitchChannelId = info.id
                if stream.enabled {
                    self.twitchChannelIdUpdated()
                }
                onComplete?()
            }
        }
    }

    func twitchLogout(stream: SettingsStream) {
        stream.twitchLoggedIn = false
        stream.twitchAccessToken = ""
        removeTwitchAccessTokenInKeychain(streamId: stream.id)
        if stream.enabled {
            reloadTwitchEventSub()
            reloadChats()
        }
    }

    func handleTwitchAccessToken(accessToken: String) {
        twitchAuthOnComplete?(accessToken)
    }

    func createStreamMarker() {
        TwitchApi(stream.twitchAccessToken, urlSession)
            .createStreamMarker(userId: stream.twitchChannelId) { data in
                if data != nil {
                    self.makeToast(title: String(localized: "Stream marker created"))
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to create stream marker"))
                }
            }
    }

    private func getStream() {
        TwitchApi(stream.twitchAccessToken, urlSession)
            .getStream(userId: stream.twitchChannelId) { data in
                guard let data else {
                    self.numberOfTwitchViewers = nil
                    return
                }
                self.numberOfTwitchViewers = data.viewer_count
            }
    }

    func updateTwitchStream(monotonicNow: ContinuousClock.Instant) {
        guard isLive, isTwitchViewersConfigured() else {
            numberOfTwitchViewers = nil
            return
        }
        guard twitchStreamUpdateTime.duration(to: monotonicNow) > .seconds(25) else {
            return
        }
        twitchStreamUpdateTime = monotonicNow
        getStream()
    }

    func startAds(seconds: Int) {
        TwitchApi(stream.twitchAccessToken, urlSession)
            .startCommercial(broadcasterId: stream.twitchChannelId, length: seconds) { data in
                if let data {
                    self.makeToast(title: data.message)
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to start commercial"))
                }
            }
    }
}

extension Model: TwitchEventSubDelegate {
    func twitchEventSubMakeErrorToast(title: String) {
        makeErrorToast(
            title: title,
            subTitle: String(localized: "Re-login to Twitch probably fixes this error")
        )
    }

    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        DispatchQueue.main.async {
            guard self.stream.twitchShowFollows else {
                return
            }
            let text = String(localized: "just followed!")
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchFollow(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New follower"),
                color: .pink,
                kind: .newFollower
            )
        }
    }

    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard !event.is_gift else {
            return
        }
        DispatchQueue.main.async {
            let text = String(localized: "just subscribed tier \(event.tierAsNumber())!")
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchSubscribe(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper"
            )
        }
    }

    func twitchEventSubChannelSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        DispatchQueue.main.async {
            let user = event.user_name ?? String(localized: "Anonymous")
            let text =
                String(localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subscriptions!")
            self.makeToast(title: "\(user) \(text)")
            self.playAlert(alert: .twitchSubscrptionGift(event))
            self.appendTwitchChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subscriptions"),
                color: .cyan,
                image: "gift"
            )
        }
    }

    func twitchEventSubChannelSubscriptionMessage(
        event: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {
        DispatchQueue.main.async {
            let text = String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
            months! \(event.message.text)
            """)
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchResubscribe(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New resubscribe"),
                color: .cyan,
                image: "party.popper"
            )
        }
    }

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        let text = String(localized: "redeemed \(event.reward.title)!")
        makeToast(title: "\(event.user_name) \(text)")
        appendTwitchChatAlertMessage(
            user: event.user_name,
            text: text,
            title: String(localized: "Reward redemption"),
            color: .blue,
            image: "medal.star"
        )
    }

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        DispatchQueue.main.async {
            let text = String(localized: "raided with a party of \(event.viewers)!")
            self.makeToast(title: "\(event.from_broadcaster_user_name) \(text)")
            self.playAlert(alert: .twitchRaid(event))
            self.appendTwitchChatAlertMessage(
                user: event.from_broadcaster_user_name,
                text: text,
                title: String(localized: "Raid"),
                color: .pink,
                image: "person.3"
            )
        }
    }

    func twitchEventSubChannelCheer(event: TwitchEventSubChannelCheerEvent) {
        DispatchQueue.main.async {
            let user = event.user_name ?? String(localized: "Anonymous")
            let bits = countFormatter.format(event.bits)
            let text = String(localized: "cheered \(bits) bits!")
            self.makeToast(title: "\(user) \(text)", subTitle: event.message)
            self.playAlert(alert: .twitchCheer(event))
            self.appendTwitchChatAlertMessage(
                user: user,
                text: "\(text) \(event.message)",
                title: String(localized: "Cheer"),
                color: .green,
                image: "suit.diamond",
                bits: ""
            )
        }
    }

    private func updateHypeTrainStatus(level: Int, progress: Int, goal: Int) {
        let percentage = Int(100 * Float(progress) / Float(goal))
        hypeTrainStatus = "LVL \(level), \(percentage)%"
    }

    private func startHypeTrainTimer(timeout: Double) {
        hypeTrainTimer.startSingleShot(timeout: timeout) { [weak self] in
            self?.removeHypeTrain()
        }
    }

    private func stopHypeTrainTimer() {
        hypeTrainTimer.stop()
    }

    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = event.progress
        hypeTrainGoal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = event.progress
        hypeTrainGoal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = 1
        hypeTrainGoal = 1
        updateHypeTrainStatus(level: event.level, progress: 1, goal: 1)
        startHypeTrainTimer(timeout: 60)
    }

    func twitchEventSubChannelAdBreakBegin(event: TwitchEventSubChannelAdBreakBeginEvent) {
        adsEndDate = Date().advanced(by: Double(event.duration_seconds))
        let duration = formatCommercialStartedDuration(seconds: event.duration_seconds)
        let kind = event.is_automatic ? String(localized: "automatic") : String(localized: "manual")
        makeToast(title: String(localized: "\(duration) \(kind) commercial starting"))
    }

    func removeHypeTrain() {
        hypeTrainLevel = nil
        hypeTrainProgress = nil
        hypeTrainGoal = nil
        hypeTrainStatus = noValue
        stopHypeTrainTimer()
    }

    private func appendTwitchChatAlertMessage(
        user: String,
        text: String,
        title: String,
        color: Color,
        image: String? = nil,
        kind: ChatHighlightKind? = nil,
        bits: String? = nil
    ) {
        appendChatMessage(platform: .twitch,
                          user: user,
                          userId: nil,
                          userColor: nil,
                          userBadges: [],
                          segments: twitchChat.createSegmentsNoTwitchEmotes(text: text, bits: bits),
                          timestamp: digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          bits: nil,
                          highlight: .init(
                              kind: kind ?? .redemption,
                              color: color,
                              image: image ?? "medal",
                              title: title
                          ), live: true)
    }

    func twitchEventSubUnauthorized() {
        twitchApiUnauthorized()
    }

    func twitchEventSubNotification(message _: String) {}
}

extension Model: TwitchChatMoblinDelegate {
    func twitchChatMoblinMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func twitchChatMoblinAppendMessage(
        user: String?,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isAction: Bool,
        isSubscriber: Bool,
        isModerator: Bool,
        bits: String?,
        highlight: ChatHighlight?
    ) {
        appendChatMessage(platform: .twitch,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: userBadges,
                          segments: segments,
                          timestamp: digitalClock,
                          timestampTime: .now,
                          isAction: isAction,
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          bits: bits,
                          highlight: highlight,
                          live: true)
    }
}

extension Model: TwitchApiDelegate {
    func twitchApiUnauthorized() {
        stream.twitchLoggedIn = false
        makeNotLoggedInToTwitchToast()
    }
}
