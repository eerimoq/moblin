extension Model {
    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled && (stream.kickChatroomId != "" || stream.kickChannelName != "")
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func hasKickPusherEmotes() -> Bool {
        return kickPusher?.hasEmotes() ?? false
    }

    func isKickViewersConfigured() -> Bool {
        return stream.kickChannelName != ""
    }

    func reloadKickViewers() {
        kickViewers?.stop()
        if isKickViewersConfigured() {
            kickViewers = KickViewers()
            kickViewers!.start(channelName: stream.kickChannelName)
        }
    }

    func reloadKickPusher() {
        kickPusher?.stop()
        kickPusher = nil
        setTextToSpeechStreamerMentions()
        if isKickPusherConfigured(), !isChatRemoteControl() {
            kickPusher = KickPusher(delegate: self,
                                    channelId: stream.kickChatroomId,
                                    channelName: stream.kickChannelName,
                                    settings: stream.chat)
            kickPusher!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func kickChannelNameUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }
}

extension Model: KickOusherDelegate {
    func kickPusherMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func kickPusherAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool,
        highlight: ChatHighlight?
    ) {
        appendChatMessage(platform: .kick,
                          messageId: messageId,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: [],
                          segments: segments,
                          timestamp: digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          bits: nil,
                          highlight: highlight,
                          live: true)
    }

    func kickPusherDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func kickPusherDeleteUser(userId: String) {
        deleteChatUser(userId: userId)
    }
}
