extension Model {
    func soopChannelNameUpdated() {
        reloadSoopChat()
        resetChat()
        reloadSoopPlatformStatus()
    }

    func soopStreamIdUpdated() {
        reloadSoopChat()
        resetChat()
    }

    func reloadSoopPlatformStatus() {
        soopPlatformStatus?.stop()
        if isSoopViewersConfigured() {
            soopPlatformStatus = SoopPlatformStatus()
            soopPlatformStatus!.start(userId: stream.soopChannelName)
        }
    }

    func updateViewersSoop() -> StreamingPlatformStatus {
        if let platformStatus = soopPlatformStatus?.platformStatus {
            return StreamingPlatformStatus(platform: .soop, status: platformStatus)
        } else {
            return StreamingPlatformStatus(platform: .soop, status: .unknown)
        }
    }

    func isSoopChatConfigured() -> Bool {
        return database.chat.enabled && stream.soopChannelName != "" && stream.soopStreamId != ""
    }

    func isSoopViewersConfigured() -> Bool {
        return !stream.soopChannelName.isEmpty
    }

    func isSoopChatConnected() -> Bool {
        return soopChat?.isConnected() ?? false
    }

    func hasSoopChatEmotes() -> Bool {
        return soopChat?.hasEmotes() ?? false
    }

    func reloadSoopChat() {
        soopChat?.stop()
        soopChat = nil
        setTextToSpeechStreamerMentions()
        if isSoopChatConfigured(), !isRemoteControlChatAndEvents(platform: .soop) {
            soopChat = SoopChat(
                model: self,
                channelName: stream.soopChannelName,
                streamId: stream.soopStreamId
            )
            soopChat!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }
}
