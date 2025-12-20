import CoreImage
import Foundation
import SwiftUI

extension Model {
    func isTwitchEventSubConfigured() -> Bool {
        return stream.twitchLoggedIn
    }

    func isTwitchEventsConnected() -> Bool {
        return twitchEventSub?.isConnected() ?? false
    }

    func isTwitchViewersConfigured() -> Bool {
        return stream.twitchChannelId != "" && stream.twitchLoggedIn
    }

    func isTwitchChatConfigured() -> Bool {
        return database.chat.enabled && stream.twitchChannelName != ""
    }

    func isTwitchChatConnected() -> Bool {
        return twitchChat?.isConnected() ?? false
    }

    func hasTwitchChatEmotes() -> Bool {
        return twitchChat?.hasEmotes() ?? false
    }

    func reloadTwitchChat() {
        twitchChat?.stop()
        setTextToSpeechStreamerMentions()
        if isTwitchChatConfigured(), !isChatRemoteControl() {
            twitchChat?.start(
                channelName: stream.twitchChannelName,
                channelId: stream.twitchChannelId,
                settings: stream.chat,
                accessToken: stream.twitchAccessToken
            )
        }
        updateChatMoreThanOneChatConfigured()
    }

    func twitchChannelNameUpdated() {
        reloadViewers()
        reloadTwitchEventSub()
        reloadTwitchChat()
        resetChat()
    }

    func twitchChannelIdUpdated() {
        reloadViewers()
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
                delegate: self
            )
            twitchEventSub!.start()
        }
    }

    func fetchTwitchRewards() {
        createTwitchApi(stream: stream)
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

    func fetchTwitchGameId(stream: SettingsStream, name: String, onComplete: @escaping (String?) -> Void) {
        createTwitchApi(stream: stream).getGames(names: [name]) {
            onComplete($0?.first?.id)
        }
    }

    func searchTwitchCategories(
        stream: SettingsStream,
        filter: String,
        onComplete: @escaping ([TwitchApiGameData]?) -> Void
    ) {
        twitchSearchCategoriesTimer.startSingleShot(timeout: 0.5) {
            self.createTwitchApi(stream: stream).searchCategories(query: filter, onComplete: onComplete)
        }
    }

    func fetchTwitchGames(
        stream: SettingsStream,
        names: [String],
        onComplete: @escaping ([TwitchApiGameData]?) -> Void
    ) {
        createTwitchApi(stream: stream).getGames(names: names, onComplete: onComplete)
    }

    func searchTwitchChannel(
        stream: SettingsStream,
        channelName: String,
        onComplete: @escaping (TwitchApiChannel?) -> Void
    ) {
        createTwitchApi(stream: stream).searchChannel(channelName: channelName, onComplete: onComplete)
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
        createTwitchApi(stream: stream).getChannelInformation(broadcasterId: stream.twitchChannelId) { info in
            guard let info else {
                return
            }
            onComplete(info)
        }
    }

    func setTwitchStreamTitle(stream: SettingsStream, title: String) {
        createTwitchApi(stream: stream).modifyChannelInformation(broadcasterId: stream.twitchChannelId,
                                                                 categoryId: nil,
                                                                 title: title) { _ in }
    }

    func setTwitchStreamCategory(stream: SettingsStream, categoryId: String) {
        createTwitchApi(stream: stream).modifyChannelInformation(broadcasterId: stream.twitchChannelId,
                                                                 categoryId: categoryId,
                                                                 title: nil) { _ in }
    }

    func twitchLogin(stream: SettingsStream, onComplete: (() -> Void)? = nil) {
        twitchAuthOnComplete = { accessToken in
            storeTwitchAccessTokenInKeychain(streamId: stream.id, accessToken: accessToken)
            stream.twitchLoggedIn = true
            stream.twitchAccessToken = accessToken
            self.showTwitchAuth = false
            self.createStreamWizard.showTwitchAuth = false
            TwitchApi(accessToken).getUserInfo { info in
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
            reloadViewers()
            reloadTwitchEventSub()
            reloadChats()
        }
    }

    func handleTwitchAccessToken(accessToken: String) {
        twitchAuthOnComplete?(accessToken)
    }

    func createStreamMarker() {
        createTwitchApi(stream: stream).createStreamMarker(userId: stream.twitchChannelId) { data in
            if data != nil {
                self.makeToast(title: String(localized: "Stream marker created"))
            } else {
                self.makeErrorToast(title: String(localized: "Failed to create stream marker"))
            }
        }
    }

    func updateTwitchStream(monotonicNow: ContinuousClock.Instant) {
        guard isLive, isTwitchViewersConfigured() else {
            twitchPlatformStatus = .unknown
            return
        }
        guard twitchStreamUpdateTime.duration(to: monotonicNow) > .seconds(25) else {
            return
        }
        twitchStreamUpdateTime = monotonicNow
        getStream()
    }

    func sendTwitchChatMessage(message: String) {
        createTwitchApi(stream: stream).sendChatMessage(broadcasterId: stream.twitchChannelId, message: message) { ok in
            if !ok {
                DispatchQueue.main.async {
                    self.makeErrorToast(title: "Failed to send to Twitch")
                }
            }
        }
    }

    func startAds(seconds: Int, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream)
            .startCommercial(broadcasterId: stream.twitchChannelId, length: seconds) {
                switch $0 {
                case .success:
                    onComplete(.success(Data()))
                case .authError:
                    onComplete(.authError)
                case .error:
                    onComplete(.error)
                }
            }
    }

    func banTwitchUser(user _: String, userId: String,
                       duration: Int?,
                       reason: String? = nil,
                       onComplete: @escaping (OperationResult) -> Void)
    {
        createTwitchApi(stream: stream).banUser(
            broadcasterId: stream.twitchChannelId,
            userId: userId,
            duration: duration,
            reason: reason,
            onComplete: onComplete
        )
    }

    func banTwitchUser(user: String, duration: Int?, reason: String?, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            self.banTwitchUser(user: user,
                               userId: twitchUser.id,
                               duration: duration,
                               reason: reason,
                               onComplete: onComplete)
        }
    }

    func unbanTwitchUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        let twitchApi = createTwitchApi(stream: stream)
        twitchApi.getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            twitchApi.unbanUser(
                broadcasterId: self.stream.twitchChannelId,
                userId: twitchUser.id,
                onComplete: onComplete
            )
        }
    }

    func modTwitchUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        let twitchApi = createTwitchApi(stream: stream)
        twitchApi.getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            twitchApi.addModerator(
                broadcasterId: self.stream.twitchChannelId,
                userId: twitchUser.id,
                onComplete: onComplete
            )
        }
    }

    func unmodTwitchUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        let twitchApi = createTwitchApi(stream: stream)
        twitchApi.getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            twitchApi.removeModerator(
                broadcasterId: self.stream.twitchChannelId,
                userId: twitchUser.id,
                onComplete: onComplete
            )
        }
    }

    func vipTwitchUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        let twitchApi = createTwitchApi(stream: stream)
        twitchApi.getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            twitchApi.addVip(
                broadcasterId: self.stream.twitchChannelId,
                userId: twitchUser.id,
                onComplete: onComplete
            )
        }
    }

    func unvipTwitchUser(user: String, onComplete: @escaping (OperationResult) -> Void) {
        let twitchApi = createTwitchApi(stream: stream)
        twitchApi.getUserByLogin(login: user) { twitchUser in
            guard let twitchUser else {
                onComplete(.error)
                return
            }
            twitchApi.removeVip(
                broadcasterId: self.stream.twitchChannelId,
                userId: twitchUser.id,
                onComplete: onComplete
            )
        }
    }

    func sendTwitchAnnouncement(message: String, color: String, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).sendAnnouncement(
            broadcasterId: stream.twitchChannelId,
            message: message,
            color: color,
            onComplete: onComplete
        )
    }

    func setTwitchSlowMode(enabled: Bool, duration: Int? = nil, onComplete: @escaping (OperationResult) -> Void) {
        var settings: [String: Any] = ["slow_mode": enabled]
        if enabled, let duration {
            settings["slow_mode_wait_time"] = duration
        }
        createTwitchApi(stream: stream).updateChatSettings(
            broadcasterId: stream.twitchChannelId,
            settings: settings,
            onComplete: onComplete
        )
    }

    func setTwitchFollowersMode(enabled: Bool, duration: Int? = nil, onComplete: @escaping (OperationResult) -> Void) {
        var settings: [String: Any] = ["follower_mode": enabled]
        if enabled, let duration {
            settings["follower_mode_duration"] = duration
        }
        createTwitchApi(stream: stream).updateChatSettings(
            broadcasterId: stream.twitchChannelId,
            settings: settings,
            onComplete: onComplete
        )
    }

    func setTwitchEmoteOnlyMode(enabled: Bool, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).updateChatSettings(
            broadcasterId: stream.twitchChannelId,
            settings: ["emote_mode": enabled],
            onComplete: onComplete
        )
    }

    func setTwitchSubscribersOnlyMode(enabled: Bool, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).updateChatSettings(
            broadcasterId: stream.twitchChannelId,
            settings: ["subscriber_mode": enabled],
            onComplete: onComplete
        )
    }

    func deleteTwitchChatMessage(messageId: String) {
        createTwitchApi(stream: stream)
            .deleteChatMessage(broadcasterId: stream.twitchChannelId, messageId: messageId) { _ in
            }
    }

    func raidTwitchChannel(channelName _: String, channelId: String, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).startRaid(broadcasterId: stream.twitchChannelId,
                                                  toBroadcasterId: channelId,
                                                  onComplete: onComplete)
    }

    func raidTwitchChannelByName(channelName: String, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).searchChannel(channelName: channelName) { channel in
            guard let channel else {
                onComplete(.error)
                return
            }
            self.raidTwitchChannel(channelName: channel.broadcaster_login,
                                   channelId: channel.id,
                                   onComplete: onComplete)
        }
    }

    func createTwitchApi(stream: SettingsStream) -> TwitchApi {
        let twitchApi = TwitchApi(stream.twitchAccessToken)
        twitchApi.delegate = self
        return twitchApi
    }

    private func getStream() {
        createTwitchApi(stream: stream).getStream(userId: stream.twitchChannelId) {
            switch $0 {
            case let .success(data):
                if let data {
                    self.twitchPlatformStatus = .live(viewerCount: data.viewer_count)
                } else {
                    self.twitchPlatformStatus = .offline
                }
            default:
                self.twitchPlatformStatus = .unknown
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
        let text = String(localized: "just followed!")
        if stream.twitchToastAlerts.follows {
            makeToast(title: "\(event.user_name) \(text)")
        }
        playAlert(alert: .twitchFollow(event))
        if stream.twitchChatAlerts.follows {
            appendTwitchChatAlertMessage(
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
        let text = String(localized: "just subscribed tier \(event.tierAsNumber())!")
        if stream.twitchToastAlerts.subscriptions {
            makeToast(title: "\(event.user_name) \(text)")
        }
        playAlert(alert: .twitchSubscribe(event))
        if stream.twitchChatAlerts.subscriptions {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper"
            )
        }
        printEventCatPrinters(event: .twitchSubscribe, username: event.user_name, message: text)
    }

    func twitchEventSubChannelSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        let user = event.user_name ?? String(localized: "Anonymous")
        let text =
            String(localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subscriptions!")
        if stream.twitchToastAlerts.giftSubscriptions {
            makeToast(title: "\(user) \(text)")
        }
        playAlert(alert: .twitchSubscrptionGift(event))
        if stream.twitchChatAlerts.giftSubscriptions {
            appendTwitchChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subscriptions"),
                color: .cyan,
                image: "gift"
            )
        }
        printEventCatPrinters(event: .twitchSubscrptionGift, username: user, message: text)
    }

    func twitchEventSubChannelSubscriptionMessage(
        event: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {
        let text = String(localized: """
        just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
        months! \(event.message.text)
        """)
        if stream.twitchToastAlerts.resubscriptions {
            makeToast(title: "\(event.user_name) \(text)")
        }
        playAlert(alert: .twitchResubscribe(event))
        if stream.twitchChatAlerts.resubscriptions {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New resubscribe"),
                color: .cyan,
                image: "party.popper"
            )
        }
        printEventCatPrinters(event: .twitchResubscribe, username: event.user_name, message: text)
    }

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        let text = String(localized: "redeemed \(event.reward.title)!")
        if stream.twitchToastAlerts.rewards {
            makeToast(title: "\(event.user_name) \(text)")
        }
        if stream.twitchChatAlerts.rewards {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "Reward redemption"),
                color: .blue,
                image: "medal.star"
            )
        }
        printEventCatPrinters(event: .twitchReward, username: event.user_name, message: text)
    }

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        let text = String(localized: "raided with a party of \(event.viewers)!")
        if stream.twitchToastAlerts.raids {
            makeToast(title: "\(event.from_broadcaster_user_name) \(text)")
        }
        playAlert(alert: .twitchRaid(event))
        if stream.twitchChatAlerts.raids {
            appendTwitchChatAlertMessage(
                user: event.from_broadcaster_user_name,
                text: text,
                title: String(localized: "Raid"),
                color: .pink,
                image: "person.3"
            )
        }
        printEventCatPrinters(event: .twitchRaid, username: event.from_broadcaster_user_name, message: text)
    }

    func twitchEventSubChannelCheer(event: TwitchEventSubChannelCheerEvent) {
        let user = event.user_name ?? String(localized: "Anonymous")
        let bits = countFormatter.format(event.bits)
        let text = String(localized: "cheered \(bits) bits!")
        if stream.twitchToastAlerts.isBitsEnabled(amount: event.bits) {
            makeToast(title: "\(user) \(text)", subTitle: event.message)
        }
        playAlert(alert: .twitchCheer(event))
        if stream.twitchChatAlerts.isBitsEnabled(amount: event.bits) {
            appendTwitchChatAlertMessage(
                user: user,
                text: "\(text) \(event.message)",
                title: String(localized: "Cheer"),
                color: .green,
                image: "suit.diamond",
                bits: ""
            )
        }
        let message = event.message.isEmpty ? text : "\(text) \(event.message)"
        printEventCatPrinters(event: .twitchCheer(amount: event.bits), username: user, message: message)
    }

    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent) {
        hypeTrain.level = event.level
        hypeTrain.progress = event.progress
        hypeTrain.goal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent) {
        hypeTrain.level = event.level
        hypeTrain.progress = event.progress
        hypeTrain.goal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent) {
        hypeTrain.level = event.level
        hypeTrain.progress = 1
        hypeTrain.goal = 1
        updateHypeTrainStatus(level: event.level, progress: 1, goal: 1)
        startHypeTrainTimer(timeout: 60)
    }

    func twitchEventSubChannelAdBreakBegin(event: TwitchEventSubChannelAdBreakBeginEvent) {
        adsEndDate = Date().advanced(by: Double(event.duration_seconds))
        let duration = formatFullDuration(seconds: event.duration_seconds)
        let kind = event.is_automatic ? String(localized: "automatic") : String(localized: "manual")
        makeToast(title: String(localized: "\(duration) \(kind) commercial starting"))
    }

    func removeHypeTrain() {
        hypeTrain.level = nil
        hypeTrain.progress = nil
        hypeTrain.goal = nil
        hypeTrain.status = noValue
        stopHypeTrainTimer()
    }

    func twitchEventSubUnauthorized() {
        twitchApiUnauthorized()
    }

    func twitchEventSubNotification(message _: String) {}

    private func updateHypeTrainStatus(level: Int, progress: Int, goal: Int) {
        let percentage = Int(100 * Float(progress) / Float(goal))
        hypeTrain.status = "LVL \(level), \(percentage)%"
    }

    private func startHypeTrainTimer(timeout: Double) {
        hypeTrain.timer.startSingleShot(timeout: timeout) { [weak self] in
            self?.removeHypeTrain()
        }
    }

    private func stopHypeTrainTimer() {
        hypeTrain.timer.stop()
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
        guard let twitchChat else {
            return
        }
        appendChatMessage(platform: .twitch,
                          messageId: nil,
                          displayName: user,
                          user: user,
                          userId: nil,
                          userColor: nil,
                          userBadges: [],
                          segments: twitchChat.createSegmentsNoTwitchEmotes(text: text, bits: bits),
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          isOwner: false,
                          bits: nil,
                          highlight: .init(
                              kind: kind ?? .redemption,
                              barColor: color,
                              image: image ?? "medal",
                              titleSegments: [ChatPostSegment(id: 0, text: title)]
                          ),
                          live: true)
    }
}

extension Model: TwitchChatDelegate {
    func twitchChatMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func twitchChatAppendMessage(
        messageId: String?,
        displayName: String,
        user: String,
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
                          messageId: messageId,
                          displayName: displayName,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: userBadges,
                          segments: segments,
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: isAction,
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          isOwner: false,
                          bits: bits,
                          highlight: highlight,
                          live: true)
    }

    func twitchChatDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func twitchChatDeleteUser(userId: String) {
        deleteChatUser(userId: userId)
    }
}

extension Model: TwitchApiDelegate {
    func twitchApiUnauthorized() {
        stream.twitchLoggedIn = false
        makeNotLoggedInToTwitchToast()
    }
}
