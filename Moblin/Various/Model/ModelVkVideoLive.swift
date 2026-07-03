import Foundation
import SwiftUI

extension Model {
    func updateViewersVkVideoLive() -> StreamingPlatformStatus {
        if let platformStatus = vkVideoLivePlatformStatus?.platformStatus {
            StreamingPlatformStatus(platform: .vkVideoLive, status: platformStatus)
        } else {
            StreamingPlatformStatus(platform: .vkVideoLive, status: .unknown)
        }
    }

    func vkVideoLiveLogin(stream: SettingsStream, onComplete: (() -> Void)? = nil) {
        vkVideoLiveAuthOnComplete = { accessToken in
            storeVkVideoLiveAccessTokenInKeychain(streamId: stream.id, accessToken: accessToken)
            stream.vkVideoLiveLoggedIn = true
            stream.vkVideoLiveAccessToken = accessToken
            self.showVkVideoLiveAuth = false
            self.createVkVideoLiveApi(stream: stream).getCurrentUser { data in
                guard let data else {
                    onComplete?()
                    return
                }
                stream.vkVideoLiveChannelNick = data.user?.nick ?? ""
                if let channelUrl = data.channel?.url, !channelUrl.isEmpty {
                    stream.vkVideoLiveChannelUrl = channelUrl
                }
                if stream.enabled {
                    self.vkVideoLiveAccessTokenUpdated()
                }
                onComplete?()
            }
        }
    }

    func vkVideoLiveLogout(stream: SettingsStream) {
        stream.vkVideoLiveLoggedIn = false
        stream.vkVideoLiveAccessToken = ""
        stream.vkVideoLiveChannelNick = ""
        removeVkVideoLiveAccessTokenInKeychain(streamId: stream.id)
        if stream.enabled {
            vkVideoLiveAccessTokenUpdated()
        }
    }

    func handleVkVideoLiveAccessToken(accessToken: String) {
        vkVideoLiveAuthOnComplete?(accessToken)
    }

    func isVkVideoLiveChatConfigured() -> Bool {
        database.chat.enabled && stream.vkVideoLiveChannelUrl != "" && stream.vkVideoLiveLoggedIn
    }

    func isVkVideoLiveChatConnected() -> Bool {
        vkVideoLiveChat?.isConnected() ?? false
    }

    func hasVkVideoLiveChatEmotes() -> Bool {
        vkVideoLiveChat?.hasEmotes() ?? false
    }

    func isVkVideoLiveViewersConfigured() -> Bool {
        stream.vkVideoLiveChannelUrl != "" && stream.vkVideoLiveLoggedIn
    }

    func reloadVkVideoLiveChat() {
        vkVideoLiveChat?.stop()
        vkVideoLiveChat = nil
        setTextToSpeechStreamerMentions()
        if isVkVideoLiveChatConfigured(), !isRemoteControlChatAndEvents(platform: .vkVideoLive) {
            vkVideoLiveChat = VkVideoLiveChat(
                delegate: self,
                channelUrl: stream.vkVideoLiveChannelUrl,
                accessToken: stream.vkVideoLiveAccessToken
            )
            vkVideoLiveChat!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func reloadVkVideoLiveViewers() {
        vkVideoLivePlatformStatus?.stop()
        if isVkVideoLiveViewersConfigured() {
            vkVideoLivePlatformStatus = VkVideoLivePlatformStatus()
            vkVideoLivePlatformStatus!.start(
                channelUrl: stream.vkVideoLiveChannelUrl,
                accessToken: stream.vkVideoLiveAccessToken
            )
        }
    }

    func vkVideoLiveChannelUrlUpdated() {
        reloadViewers()
        reloadVkVideoLiveChat()
        reloadVkVideoLiveViewers()
        resetChat()
    }

    func vkVideoLiveAccessTokenUpdated() {
        reloadViewers()
        reloadVkVideoLiveChat()
        reloadVkVideoLiveViewers()
        resetChat()
    }

    func makeNotLoggedInToVkVideoLiveToast() {
        makeErrorToast(
            title: String(localized: "Not logged in to VK Video Live"),
            subTitle: String(localized: "Please login again")
        )
    }

    func sendVkVideoLiveChatMessage(message: String) {
        if let streamId = vkVideoLiveChat?.getStreamId() {
            sendVkVideoLiveChatMessage(streamId: streamId, message: message)
        } else {
            createVkVideoLiveApi(stream: stream)
                .getChannel(channelUrl: stream.vkVideoLiveChannelUrl) { data in
                    guard let streamId = data?.stream?.id else {
                        return
                    }
                    self.sendVkVideoLiveChatMessage(streamId: streamId, message: message)
                }
        }
    }

    private func sendVkVideoLiveChatMessage(streamId: String, message: String) {
        createVkVideoLiveApi(stream: stream).sendChatMessage(
            channelUrl: stream.vkVideoLiveChannelUrl,
            streamId: streamId,
            message: message
        ) { _ in }
    }

    func getVkVideoLiveStreamInfo(
        stream: SettingsStream,
        onComplete: @escaping (VkVideoLiveStream?) -> Void
    ) {
        createVkVideoLiveApi(stream: stream).getChannel(channelUrl: stream.vkVideoLiveChannelUrl) { data in
            onComplete(data?.stream)
        }
    }

    func setVkVideoLiveStreamTitle(
        stream: SettingsStream,
        title: String,
        onComplete: @escaping (OperationResult) -> Void
    ) {
        editVkVideoLiveStream(stream: stream, title: title, category: nil) {
            if !$0.isSuccessful() {
                self.makeErrorToast(title: String(localized: "Failed to set stream title"))
            }
            onComplete($0)
        }
    }

    func setVkVideoLiveStreamCategory(stream: SettingsStream, category: VkVideoLiveCategory) {
        editVkVideoLiveStream(stream: stream, title: nil, category: category) {
            if !$0.isSuccessful() {
                self.makeErrorToast(title: String(localized: "Failed to set stream category"))
            }
        }
    }

    // The stream edit endpoint requires both title and category, so fill in
    // whichever was not given from the current stream.
    private func editVkVideoLiveStream(stream: SettingsStream,
                                       title: String?,
                                       category: VkVideoLiveCategory?,
                                       onComplete: @escaping (OperationResult) -> Void)
    {
        let api = createVkVideoLiveApi(stream: stream)
        let channelUrl = stream.vkVideoLiveChannelUrl
        api.getChannel(channelUrl: channelUrl) { data in
            guard let currentStream = data?.stream else {
                onComplete(.error)
                return
            }
            api.editStream(channelUrl: channelUrl,
                           title: title ?? currentStream.title,
                           category: category ?? currentStream.category,
                           onComplete: onComplete)
        }
    }

    func setVkVideoLiveSlowMode(messageInterval: Int?, onComplete: @escaping (OperationResult) -> Void) {
        editVkVideoLiveChatSettings(onComplete: onComplete) { settings in
            settings.any_message_timeout = Int64(messageInterval ?? 0)
        }
    }

    func setVkVideoLiveEmoteOnlyMode(enabled: Bool, onComplete: @escaping (OperationResult) -> Void) {
        editVkVideoLiveChatSettings(onComplete: onComplete) { settings in
            if enabled {
                settings.mode = VkVideoLiveChatMode(only_smiles: VkVideoLiveChatModeOnlySmiles())
            } else {
                settings.mode = VkVideoLiveChatMode(general: settings.mode?.general
                    ?? VkVideoLiveChatModeGeneral())
            }
        }
    }

    private func editVkVideoLiveChatSettings(
        onComplete: @escaping (OperationResult) -> Void,
        modify: @escaping (inout VkVideoLiveChatSettings) -> Void
    ) {
        let api = createVkVideoLiveApi(stream: stream)
        let channelUrl = stream.vkVideoLiveChannelUrl
        api.getChatSettings(channelUrl: channelUrl) { settings in
            guard var settings else {
                onComplete(.error)
                return
            }
            modify(&settings)
            api.editChatSettings(channelUrl: channelUrl, settings: settings, onComplete: onComplete)
        }
    }

    func searchVkVideoLiveCategories(
        stream: SettingsStream,
        query: String,
        onComplete: @escaping ([VkVideoLiveCategory]) -> Void
    ) {
        vkVideoLiveSearchCategoriesTimer.startSingleShot(timeout: 0.5) {
            let api = self.createVkVideoLiveApi(stream: stream)
            api.searchCategories(query: query, type: "game") { gameCategories in
                api.searchCategories(query: query, type: "irl") { irlCategories in
                    var categories: [VkVideoLiveCategory] = []
                    for category in (irlCategories ?? []) + (gameCategories ?? [])
                        where !categories.contains(where: { $0.id == category.id })
                    {
                        categories.append(category)
                    }
                    onComplete(categories)
                }
            }
        }
    }

    func createVkVideoLiveApi(stream: SettingsStream) -> VkVideoLiveApi {
        let api = VkVideoLiveApi(accessToken: stream.vkVideoLiveAccessToken)
        api.delegate = self
        return api
    }
}

extension Model: @preconcurrency VkVideoLiveChatDelegate {
    func vkVideoLiveChatAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isModerator: Bool,
        isOwner: Bool
    ) {
        appendChatMessage(platform: .vkVideoLive,
                          messageId: messageId,
                          displayName: user,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: userBadges,
                          segments: segments,
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: isModerator,
                          isOwner: isOwner,
                          bits: nil,
                          highlight: nil,
                          live: true)
    }

    func vkVideoLiveChatDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func vkVideoLiveChatRewardRedemption(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        segments: [ChatPostSegment]
    ) {
        appendChatMessage(platform: .vkVideoLive,
                          messageId: messageId,
                          displayName: user,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: [],
                          segments: segments,
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          isOwner: false,
                          bits: nil,
                          highlight: .init(
                              kind: .redemption,
                              barColor: .blue,
                              image: "medal.star",
                              titleSegments: [ChatPostSegment(
                                  id: 0,
                                  text: String(localized: "Reward redemption")
                              )]
                          ),
                          live: true)
    }
}

extension Model: @preconcurrency VkVideoLiveApiDelegate {
    func vkVideoLiveApiUnauthorized() {
        stream.vkVideoLiveLoggedIn = false
    }
}
