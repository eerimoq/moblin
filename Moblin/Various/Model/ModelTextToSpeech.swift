extension Model {
    func toggleTextToSpeechPaused() {
        if getGlobalButton(type: .pauseTts)?.isOn == false {
            chatTextToSpeech.pause()
        } else {
            chatTextToSpeech.play()
        }
        toggleGlobalButton(type: .pauseTts)
        updateQuickButtonStates()
    }

    func isTextToSpeechEnabledForMessage(post: ChatPost) -> Bool {
        guard database.chat.textToSpeechEnabled, post.live, post.filter?.textToSpeech != false else {
            return false
        }
        if database.chat.textToSpeechSubscribersOnly {
            guard post.isSubscriber else {
                return false
            }
        }
        if post.bits != nil {
            return false
        }
        if isAlertMessage(post: post) && isTextToSpeechEnabledForAnyAlertWidget() {
            return false
        }
        return post.user != nil
    }

    private func isTextToSpeechEnabledForAnyAlertWidget() -> Bool {
        for alertEffect in enabledAlertsEffects {
            let settings = alertEffect.getSettings()
            if settings.twitch.follows.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch.subscriptions.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch.raids.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch.cheers.isTextToSpeechEnabled() {
                return true
            }
        }
        return false
    }

    func setTextToSpeechStreamerMentions() {
        var streamerMentions: [String] = []
        if isTwitchChatConfigured() {
            streamerMentions.append("@\(stream.twitchChannelName)")
        }
        if isKickPusherConfigured() {
            streamerMentions.append("@\(stream.kickChannelName)")
        }
        if isSoopChatConfigured() {
            streamerMentions.append("@\(stream.soopChannelName)")
        }
        chatTextToSpeech.setStreamerMentions(streamerMentions: streamerMentions)
    }

    func previewTextToSpeech(username: String, message: String) {
        chatTextToSpeech.sayPreview(user: username, message: message)
    }
}
