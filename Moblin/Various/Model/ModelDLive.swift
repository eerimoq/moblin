import Foundation
import SwiftUI

extension Model {
    func isDLiveChatConfigured() -> Bool {
        return database.chat.enabled && stream.dLiveUsername != ""
    }

    func isDLiveChatConnected() -> Bool {
        return dliveChat?.isConnected() ?? false
    }

    func hasDLiveChatEmotes() -> Bool {
        return dliveChat?.hasEmotes() ?? false
    }

    func reloadDLiveChat() {
        dliveChat?.stop()
        dliveChat = nil
        setTextToSpeechStreamerMentions()
        if isDLiveChatConfigured(), !isChatRemoteControl() {
            dliveChat = DLiveChat(delegate: self)
            dliveChat?.start(streamerUsername: stream.dLiveUsername)
        }
        updateChatMoreThanOneChatConfigured()
    }

    func dliveStreamerUsernameUpdated() {
        reloadDLiveChat()
        resetChat()
    }
}

extension Model: DLiveChatDelegate {
    func dliveChatMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func dliveChatAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool
    ) {
        appendChatMessage(platform: .dlive,
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
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          isOwner: false,
                          bits: nil,
                          highlight: nil,
                          live: true)
    }

    func dliveChatDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func dliveChatDeleteUser(userId: String) {
        deleteChatUser(userId: userId)
    }
}
