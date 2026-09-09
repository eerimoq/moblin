import CoreImage
import Foundation
import SwiftUI

extension Model {
    func updateViewersTwitch() -> StreamingPlatformStatus {
        StreamingPlatformStatus(platform: .twitch, status: twitchPlatformStatus)
    }

    func isTwitchEventSubConfigured() -> Bool {
        stream.twitchLoggedIn
    }

    func isTwitchEventsConnected() -> Bool {
        twitchEventSub?.isConnected() ?? false
    }

    func isTwitchViewersConfigured() -> Bool {
        stream.twitchChannelId != "" && stream.twitchLoggedIn
    }

    func isTwitchChatConfigured() -> Bool {
        database.chat.enabled && stream.twitchChannelName != ""
    }

    func isTwitchChatConnected() -> Bool {
        twitchChat?.isConnected() ?? false
    }

    func hasTwitchChatEmotes() -> Bool {
        twitchChat?.hasEmotes() ?? false
    }

    func reloadTwitchChat() {
        twitchChat?.stop()
        setTextToSpeechStreamerMentions()
        if isTwitchChatConfigured(), !isRemoteControlChatAndEvents(platform: .twitch) {
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

    func searchTwitchChannels(
        stream: SettingsStream,
        filter: String,
        onComplete: @escaping (NetworkResponse<[TwitchApiChannel]>) -> Void
    ) {
        twitchSearchChannelsTimer.startSingleShot(timeout: 0.5) {
            self.createTwitchApi(stream: stream).searchChannels(filter: filter,
                                                                liveOnly: true,
                                                                onComplete: onComplete)
        }
    }

    func getTwitchFollowedStreams(
        stream: SettingsStream,
        onComplete: @escaping (NetworkResponse<[TwitchApiStreamData]>) -> Void
    ) {
        createTwitchApi(stream: stream).getFollowedStreams(userId: stream.twitchChannelId,
                                                           onComplete: onComplete)
    }

    func getTwitchStreams(
        stream: SettingsStream,
        userIds: [String],
        onComplete: @escaping ([TwitchApiStreamData]?) -> Void
    ) {
        createTwitchApi(stream: stream).getStreams(userIds: userIds, onComplete: onComplete)
    }

    func getTwitchUsers(
        stream: SettingsStream,
        userIds: [String],
        onComplete: @escaping ([TwitchApiUser]?) -> Void
    ) {
        createTwitchApi(stream: stream).getUsersByIds(ids: userIds, onComplete: onComplete)
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
            stream.twitchWantsToBeLoggedIn = true
            stream.twitchNotLoggedInCount = 0
            stream.twitchAccessToken = accessToken
            self.showTwitchAuth = false
            self.showModerationAuth = false
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
        stream.twitchWantsToBeLoggedIn = false
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

    func makeNotLoggedInToTwitchToastIfNeeded() {
        guard stream.twitchWantsToBeLoggedIn, !stream.twitchLoggedIn else {
            return
        }
        stream.twitchNotLoggedInCount += 1
        if stream.twitchNotLoggedInCount >= maxNotLoggedInToastCount {
            stream.twitchWantsToBeLoggedIn = false
        }
        makeNotLoggedInToToast(platform: .twitch)
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

    func sendTwitchChatMessage(message: String, onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).sendChatMessage(broadcasterId: stream.twitchChannelId,
                                                        message: message,
                                                        onComplete: onComplete)
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

    func banTwitchUser(
        user: String,
        duration: Int?,
        reason: String?,
        onComplete: @escaping (OperationResult) -> Void
    ) {
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

    func sendTwitchAnnouncement(
        message: String,
        color: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        createTwitchApi(stream: stream).sendAnnouncement(
            broadcasterId: stream.twitchChannelId,
            message: message,
            color: color,
            onComplete: onComplete
        )
    }

    func setTwitchSlowMode(
        enabled: Bool,
        duration: Int? = nil,
        onComplete: @escaping (OperationResult) -> Void
    ) {
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

    func setTwitchFollowersMode(
        enabled: Bool,
        duration: Int? = nil,
        onComplete: @escaping (OperationResult) -> Void
    ) {
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

    func startRaidTwitchChannel(
        channelId: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        createTwitchApi(stream: stream).startRaid(broadcasterId: stream.twitchChannelId,
                                                  toBroadcasterId: channelId,
                                                  onComplete: onComplete)
    }

    func cancelRaidTwitchChannel(onComplete: @escaping (OperationResult) -> Void) {
        createTwitchApi(stream: stream).cancelRaid(broadcasterId: stream.twitchChannelId,
                                                   onComplete: onComplete)
    }

    func twitchRaidStarted(channelLogin: String, channelName: String) {
        raid.state = .ongoing
        raid.message = String(localized: "Raiding \(channelName)")
        raid.progress.progress = 0
        raid.progress.goal = 90
        raid.channelId = ""
        raid.channelName = channelName
        searchTwitchChannel(stream: stream, channelName: channelLogin) {
            self.raid.channelImage = $0?.thumbnail_url ?? ""
            self.raid.channelId = $0?.id ?? ""
        }
    }

    func twitchRaidCancelled() {
        raid.message = String(localized: "Raid cancelled")
        raid.state = .completed
    }

    func twitchRaidCompleted() {
        raid.state = .completed
        raid.message = String(localized: "Raid completed!")
        appendTwitchRaidSent(channelId: raid.channelId, channelName: raid.channelName)
        raid.timer.startSingleShot(timeout: 60) {
            self.removeRaid()
        }
    }

    func updateTwitchRaid() {
        guard raid.state == .ongoing else {
            return
        }
        if raid.progress.progress < raid.progress.goal {
            raid.progress.progress += 1
        }
    }

    func removeRaid() {
        raid.state = .idle
        raid.channelImage = ""
        raid.channelId = ""
        raid.channelName = ""
        raid.timer.stop()
    }

    private func appendTwitchRaidSent(channelId: String, channelName: String) {
        guard !channelId.isEmpty else {
            return
        }
        stream.twitchRaidsSent = appendTwitchRaidChannel(stream.twitchRaidsSent,
                                                         channelId: channelId,
                                                         channelName: channelName)
        storeSettings()
    }

    private func appendTwitchRaidReceived(channelId: String, channelName: String) {
        guard !channelId.isEmpty, channelId != stream.twitchChannelId else {
            return
        }
        stream.twitchRaidsReceived = appendTwitchRaidChannel(stream.twitchRaidsReceived,
                                                             channelId: channelId,
                                                             channelName: channelName)
        storeSettings()
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

    private func parseTwitchTimestamp(_ value: String?) -> Date? {
        guard var value else {
            return nil
        }
        if let index = value.firstIndex(of: ".") {
            value = String(value[..<index]) + "Z"
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }

    private func formatTwitchCountdown(_ date: Date) -> String {
        uptimeFormatter.string(from: max(0, date.timeIntervalSinceNow).rounded(.up)) ?? ""
    }

    private func updateTwitchPoll(event: TwitchEventSubChannelPollEvent, state: TwitchPollState) {
        twitchPoll.state = state
        twitchPoll.title = event.title
        twitchPoll.choices = event.choices.map {
            TwitchPollChoice(id: $0.id, title: $0.title, votes: $0.votes ?? 0)
        }
        twitchPoll.totalVotes = twitchPoll.choices.reduce(0) { $0 + $1.votes }
        twitchPoll.endsAt = parseTwitchTimestamp(event.ends_at)
    }

    func updateTwitchPollCountdown() {
        guard twitchPoll.state == .ongoing, let endsAt = twitchPoll.endsAt else {
            return
        }
        let countdown = formatTwitchCountdown(endsAt)
        twitchPoll.message = String(localized: "Ends in \(countdown)")
    }

    func removeTwitchPoll() {
        twitchPoll.state = .idle
        twitchPoll.timer.stop()
    }

    private func updateTwitchPrediction(
        event: TwitchEventSubChannelPredictionEvent,
        state: TwitchPredictionState
    ) {
        twitchPrediction.state = state
        twitchPrediction.title = event.title
        twitchPrediction.outcomes = event.outcomes.map {
            TwitchPredictionOutcome(id: $0.id,
                                    title: $0.title,
                                    color: $0.color,
                                    users: $0.users ?? 0,
                                    channelPoints: $0.channel_points ?? 0,
                                    winner: $0.id == event.winning_outcome_id)
        }
        twitchPrediction.totalChannelPoints = twitchPrediction.outcomes.reduce(0) { $0 + $1.channelPoints }
        twitchPrediction.locksAt = parseTwitchTimestamp(event.locks_at)
    }

    func updateTwitchPredictionCountdown() {
        guard twitchPrediction.state == .ongoing, let locksAt = twitchPrediction.locksAt else {
            return
        }
        let countdown = formatTwitchCountdown(locksAt)
        twitchPrediction.message = String(localized: "Locks in \(countdown)")
    }

    func removeTwitchPrediction() {
        twitchPrediction.state = .idle
        twitchPrediction.timer.stop()
    }

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

    func removeHypeTrain() {
        hypeTrain.level = nil
        hypeTrain.progress = nil
        hypeTrain.status = noValue
        stopHypeTrainTimer()
    }

    private func appendTwitchChatAlertMessage(
        user: String,
        text: String,
        title: String,
        color: Color,
        image: String,
        kind: ChatHighlightKind,
        sharedChat: TwitchEventSubSharedChat?,
        bits: String? = nil
    ) {
        guard let twitchChat else {
            return
        }
        let segments = twitchChat.createSegmentsNoTwitchEmotes(text: text, bits: bits)
        let highlight = ChatHighlight(
            kind: kind,
            barColor: color,
            image: image,
            titleSegments: [ChatPostSegment(id: 0, text: title)]
        )
        if let sharedChat {
            twitchChat.getSourceChannelIcon(sourceRoomId: sharedChat.broadcasterUserId) { sourceChannelIcon in
                self.appendTwitchChatAlertMessage(user: user,
                                                  segments: segments,
                                                  highlight: highlight,
                                                  sourceChannelIcon: sourceChannelIcon)
            }
        } else {
            appendTwitchChatAlertMessage(
                user: user,
                segments: segments,
                highlight: highlight,
                sourceChannelIcon: nil
            )
        }
    }

    private func appendTwitchChatAlertMessage(
        user: String,
        segments: [ChatPostSegment],
        highlight: ChatHighlight,
        sourceChannelIcon: URL?
    ) {
        appendChatMessage(platform: .twitch,
                          messageId: nil,
                          displayName: user,
                          user: user,
                          userId: nil,
                          userColor: nil,
                          userBadges: [],
                          segments: segments,
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          isOwner: false,
                          bits: nil,
                          highlight: highlight,
                          live: true,
                          sourceChannelIcon: sourceChannelIcon)
    }

    private func isTwitchSharedChatAlertEnabled(
        _ sharedChat: TwitchEventSubSharedChat?,
        alerts: SettingsTwitchAlerts
    ) -> Bool {
        sharedChat == nil || alerts.sharedChat
    }
}

extension Model: @preconcurrency TwitchEventSubDelegate {
    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        latestFollower = event.user_name
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
                image: "medal",
                kind: .newFollower,
                sharedChat: nil
            )
        }
        printEventCatPrinters(event: .twitchFollow, username: event.user_name, message: text)
    }

    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard !event.is_gift else {
            return
        }
        let text = if event.isPrime() {
            String(localized: "just subscribed with Prime!")
        } else {
            String(localized: "just subscribed tier \(event.tierAsNumber())!")
        }
        if stream.twitchToastAlerts.subscriptions,
           isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
        {
            makeToast(title: "\(event.user_name) \(text)")
        }
        guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
            return
        }
        playAlert(alert: .twitchSubscribe(event))
        if stream.twitchChatAlerts.subscriptions {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper",
                kind: .other,
                sharedChat: event.sharedChat
            )
        }
        printEventCatPrinters(event: .twitchSubscribe, username: event.user_name, message: text)
        latestSubscriber = event.user_name
    }

    func twitchEventSubChannelSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        let user = event.user_name ?? String(localized: "Anonymous")
        let text =
            String(localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subscriptions!")
        if stream.twitchToastAlerts.giftSubscriptions,
           isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
        {
            makeToast(title: "\(user) \(text)")
        }
        guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
            return
        }
        playAlert(alert: .twitchSubscrptionGift(event))
        if stream.twitchChatAlerts.giftSubscriptions {
            appendTwitchChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subscriptions"),
                color: .cyan,
                image: "gift",
                kind: .other,
                sharedChat: event.sharedChat
            )
        }
        printEventCatPrinters(event: .twitchSubscrptionGift, username: user, message: text)
        latestSubscriber = user
    }

    func twitchEventSubChannelSubscriptionMessage(
        event: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {
        let text = if let streakMonths = event.streak_months {
            String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) months, \
            \(streakMonths) in a row! \(event.message.text)
            """)
        } else {
            String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
            months! \(event.message.text)
            """)
        }
        if stream.twitchToastAlerts.resubscriptions,
           isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
        {
            makeToast(title: "\(event.user_name) \(text)")
        }
        guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
            return
        }
        playAlert(alert: .twitchResubscribe(event))
        if stream.twitchChatAlerts.resubscriptions {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New resubscribe"),
                color: .cyan,
                image: "party.popper",
                kind: .other,
                sharedChat: event.sharedChat
            )
        }
        printEventCatPrinters(event: .twitchResubscribe, username: event.user_name, message: text)
        latestSubscriber = event.user_name
    }

    func twitchEventSubChannelSubscriptionUpgrade(
        event: TwitchEventSubNotificationChannelSubscriptionUpgradeEvent
    ) {
        let text = if let tier = event.tierAsNumber() {
            String(localized: "just converted their Prime subscription to tier \(tier)!")
        } else {
            String(localized: "just continued their gift subscription!")
        }
        if stream.twitchToastAlerts.subscriptions,
           isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
        {
            makeToast(title: "\(event.user_name) \(text)")
        }
        guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
            return
        }
        playAlert(alert: .twitchSubscriptionUpgrade(event))
        if stream.twitchChatAlerts.subscriptions {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper",
                kind: .other,
                sharedChat: event.sharedChat
            )
        }
        printEventCatPrinters(event: .twitchSubscribe, username: event.user_name, message: text)
        latestSubscriber = event.user_name
    }

    func twitchEventSubChannelWatchStreak(event: TwitchEventSubNotificationChannelWatchStreakEvent) {
        let text = if event.message.text.isEmpty {
            String(localized: "just watched \(event.streak_count) streams in a row!")
        } else {
            String(localized: "just watched \(event.streak_count) streams in a row! \(event.message.text)")
        }
        if stream.twitchToastAlerts.isWatchStreakEnabled(count: event.streak_count),
           isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
        {
            makeToast(title: "\(event.user_name) \(text)")
        }
        guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
            return
        }
        if stream.twitchChatAlerts.isWatchStreakEnabled(count: event.streak_count) {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "Watch streak"),
                color: .orange,
                image: "flame",
                kind: .other,
                sharedChat: event.sharedChat
            )
        }
    }

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        let text = String(localized: "redeemed \(event.reward.title)!")
        if stream.twitchToastAlerts.rewards {
            makeToast(title: "\(event.user_name) \(text)")
        }
        if false {
            playAlert(alert: .twitchRedemption(event))
        }
        if stream.twitchChatAlerts.rewards {
            appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "Reward redemption"),
                color: .blue,
                image: "medal.star",
                kind: .redemption,
                sharedChat: nil
            )
        }
        printEventCatPrinters(event: .twitchReward, username: event.user_name, message: text)
    }

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        if event.sharedChat == nil, event.from_broadcaster_user_id == stream.twitchChannelId {
            twitchRaidCompleted()
        } else {
            appendTwitchRaidReceived(channelId: event.from_broadcaster_user_id,
                                     channelName: event.from_broadcaster_user_name)
            let text = String(localized: "raided with a party of \(event.viewers)!")
            if stream.twitchToastAlerts.raids,
               isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchToastAlerts)
            {
                makeToast(title: "\(event.from_broadcaster_user_name) \(text)")
            }
            guard isTwitchSharedChatAlertEnabled(event.sharedChat, alerts: stream.twitchChatAlerts) else {
                return
            }
            playAlert(alert: .twitchRaid(event))
            if stream.twitchChatAlerts.raids {
                appendTwitchChatAlertMessage(
                    user: event.from_broadcaster_user_name,
                    text: text,
                    title: String(localized: "Raid"),
                    color: .pink,
                    image: "person.3",
                    kind: .other,
                    sharedChat: event.sharedChat
                )
            }
            printEventCatPrinters(
                event: .twitchRaid,
                username: event.from_broadcaster_user_name,
                message: text
            )
        }
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
                kind: .other,
                sharedChat: nil,
                bits: ""
            )
        }
        let message = event.message.isEmpty ? text : "\(text) \(event.message)"
        printEventCatPrinters(event: .twitchCheer(amount: event.bits), username: user, message: message)
    }

    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent) {
        hypeTrain.level = event.level
        hypeTrain.progress = ProgressBar()
        hypeTrain.progress?.progress = Float(event.progress)
        hypeTrain.progress?.goal = Float(event.goal)
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: String(localized: "started a hype train!"),
            title: String(localized: "Hype train started"),
            color: .purple,
            image: "train.side.front.car",
            kind: .other,
            sharedChat: nil
        )
    }

    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent) {
        hypeTrain.level = event.level
        if hypeTrain.progress == nil {
            hypeTrain.progress = ProgressBar()
        }
        hypeTrain.progress?.progress = Float(event.progress)
        hypeTrain.progress?.goal = Float(event.goal)
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent) {
        hypeTrain.level = event.level
        if hypeTrain.progress == nil {
            hypeTrain.progress = ProgressBar()
        }
        hypeTrain.progress?.progress = 1
        hypeTrain.progress?.goal = 1
        updateHypeTrainStatus(level: event.level, progress: 1, goal: 1)
        startHypeTrainTimer(timeout: 60)
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: String(localized: "ended the hype train at level \(event.level)!"),
            title: String(localized: "Hype train ended"),
            color: .purple,
            image: "train.side.rear.car",
            kind: .other,
            sharedChat: nil
        )
    }

    func twitchEventSubChannelAdBreakBegin(event: TwitchEventSubChannelAdBreakBeginEvent) {
        adsEndDate = Date().advanced(by: Double(event.duration_seconds))
        let duration = formatShortDuration(seconds: event.duration_seconds)
        let kind = event.is_automatic ? String(localized: "automatic") : String(localized: "manual")
        makeToast(title: String(localized: "\(duration) \(kind) commercial starting"))
    }

    private func updateOngoingTwitchPoll(event: TwitchEventSubChannelPollEvent) {
        updateTwitchPoll(event: event, state: .ongoing)
        updateTwitchPollCountdown()
        twitchPoll.timer.startSingleShot(timeout: 1900) { [weak self] in
            self?.removeTwitchPoll()
        }
    }

    func twitchEventSubChannelPollBegin(event: TwitchEventSubChannelPollEvent) {
        updateOngoingTwitchPoll(event: event)
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: String(localized: "started a poll: \(event.title)"),
            title: String(localized: "Poll started"),
            color: .indigo,
            image: "chart.bar",
            kind: .other,
            sharedChat: nil
        )
    }

    func twitchEventSubChannelPollProgress(event: TwitchEventSubChannelPollEvent) {
        updateOngoingTwitchPoll(event: event)
    }

    func twitchEventSubChannelPollEnd(event: TwitchEventSubChannelPollEvent) {
        updateTwitchPoll(event: event, state: .completed)
        let text: String
        if event.status != "archived" {
            twitchPoll.message = String(localized: "Poll ended")
            if let winner = twitchPoll.choices.max(by: { $0.votes < $1.votes }) {
                text = String(localized: "ended the poll: \(event.title) Winner: \(winner.title)")
            } else {
                text = String(localized: "ended the poll: \(event.title)")
            }
        } else {
            return
        }
        twitchPoll.timer.startSingleShot(timeout: 60) { [weak self] in
            self?.removeTwitchPoll()
        }
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: text,
            title: String(localized: "Poll ended"),
            color: .indigo,
            image: "chart.bar",
            kind: .other,
            sharedChat: nil
        )
    }

    private func updateOngoingTwitchPrediction(event: TwitchEventSubChannelPredictionEvent) {
        updateTwitchPrediction(event: event, state: .ongoing)
        updateTwitchPredictionCountdown()
        twitchPrediction.timer.startSingleShot(timeout: 1900) { [weak self] in
            self?.removeTwitchPrediction()
        }
    }

    func twitchEventSubChannelPredictionBegin(event: TwitchEventSubChannelPredictionEvent) {
        updateOngoingTwitchPrediction(event: event)
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: String(localized: "started a prediction: \(event.title)"),
            title: String(localized: "Prediction started"),
            color: .mint,
            image: "questionmark.diamond",
            kind: .other,
            sharedChat: nil
        )
    }

    func twitchEventSubChannelPredictionProgress(event: TwitchEventSubChannelPredictionEvent) {
        updateOngoingTwitchPrediction(event: event)
    }

    func twitchEventSubChannelPredictionLock(event: TwitchEventSubChannelPredictionEvent) {
        updateTwitchPrediction(event: event, state: .locked)
        twitchPrediction.message = String(localized: "Locked, waiting for outcome")
        twitchPrediction.timer.stop()
    }

    func twitchEventSubChannelPredictionEnd(event: TwitchEventSubChannelPredictionEvent) {
        updateTwitchPrediction(event: event, state: .completed)
        let text: String
        if let winner = twitchPrediction.outcomes.first(where: { $0.winner }) {
            twitchPrediction.message = String(localized: "Outcome: \(winner.title)")
            text = String(localized: "ended the prediction: \(event.title) Outcome: \(winner.title)")
        } else {
            twitchPrediction.message = String(localized: "Prediction cancelled")
            text = String(localized: "cancelled the prediction: \(event.title)")
        }
        twitchPrediction.timer.startSingleShot(timeout: 60) { [weak self] in
            self?.removeTwitchPrediction()
        }
        appendTwitchChatAlertMessage(
            user: stream.twitchChannelName,
            text: text,
            title: String(localized: "Prediction ended"),
            color: .mint,
            image: "trophy",
            kind: .other,
            sharedChat: nil
        )
    }

    func twitchEventSubChannelModerate(event: TwitchEventSubChannelModerateEvent) {
        switch event.action {
        case "raid":
            guard let raid = event.raid else {
                return
            }
            twitchRaidStarted(channelLogin: raid.user_login, channelName: raid.user_name)
        case "unraid":
            twitchRaidCancelled()
        default:
            break
        }
    }

    func twitchEventSubUnauthorized() {
        twitchApiUnauthorized()
    }

    func twitchEventSubNotification(message _: String) {}
}

extension Model: @preconcurrency TwitchChatDelegate {
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
        highlight: ChatHighlight?,
        sourceChannelIcon: URL?
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
                          live: true,
                          sourceChannelIcon: sourceChannelIcon)
    }

    func twitchChatDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func twitchChatDeleteUser(userId: String) {
        deleteChatUser(userId: userId)
    }
}

extension Model: @preconcurrency TwitchApiDelegate {
    func twitchApiUnauthorized() {
        guard stream.twitchLoggedIn else {
            return
        }
        stream.twitchLoggedIn = false
        makeNotLoggedInToToast(platform: .twitch)
    }
}
