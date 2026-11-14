import Foundation

private struct StreamUpdateEffects {
    var reload = ChangeTracker()
    var portrait = false
    var pictureInPicture = ChangeTracker()
    var obsWebSocket = ChangeTracker()
    var location = ChangeTracker()
    var chats = ChangeTracker()
    var lowLightBoost = false
    var bitrate = false
    var audioBitrate = false
    var timecodes = ChangeTracker()
    var adaptiveBitrateAlgorithm = false
    var adaptiveBitrate = ChangeTracker()
    var connectionPriorities = ChangeTracker()
    var cleanRecordings = false
    var cleanSnapshots = false
    var replayEnabled = false
    var replayLayout = ChangeTracker()
    var twitchChannelName = false
    var twitchChannelId = false
    var kickChannelName = false
    var youTubeVideoIds = false
    var soopChannelName = false
    var soopStreamId = false
    var openStreamingPlatformUrl = false
    var openStreamingPlatformChannelId = false
}

extension Model {
    func remoteControlGetStream(id: UUID, secrets: Bool) -> SettingsStream? {
        guard let stream = findStream(id: id), let copy = stream.deepCopy() else {
            return nil
        }
        copy.removeAccessTokens()
        if !secrets {
            copy.removeSecrets()
        }
        return copy
    }

    func remoteControlCreateStream(stream: SettingsStream, secrets: Bool) -> Bool {
        stream.removeAccessTokens()
        if !secrets {
            stream.keepSecrets(from: SettingsStream(name: ""))
        }
        guard !database.streams.contains(where: { $0.id == stream.id }) else {
            return false
        }
        if stream.name.isEmpty {
            stream.name = makeUniqueName(name: SettingsStream.baseName, existingNames: database.streams)
        }
        let newStream = SettingsStream(name: stream.name)
        newStream.id = stream.id
        newStream.srt.connectionPriorities.priorities = stream.srt.connectionPriorities.priorities.map {
            let priority = SettingsStreamSrtConnectionPriority(name: $0.name)
            priority.id = $0.id
            priority.relayId = $0.relayId
            return priority
        }
        guard remoteControlApplyStreamUpdate(stream: newStream, new: stream, creating: true) else {
            return false
        }
        removeTwitchAccessTokenInKeychain(streamId: newStream.id)
        removeKickAccessTokenInKeychain(streamId: newStream.id)
        removeYouTubeAuthStateInKeychain(streamId: newStream.id)
        database.streams.append(newStream)
        return true
    }

    func remoteControlUpdateStream(stream: SettingsStream, secrets: Bool) -> Bool {
        stream.removeAccessTokens()
        guard let oldStream = findStream(id: stream.id) else {
            return false
        }
        if !secrets {
            stream.keepSecrets(from: oldStream)
        }
        return remoteControlApplyStreamUpdate(stream: oldStream, new: stream, creating: false)
    }

    func remoteControlDeleteStream(id: UUID) -> Bool {
        guard let stream = findStream(id: id), !stream.enabled else {
            return false
        }
        database.streams.removeAll { $0 === stream }
        return true
    }

    private func remoteControlApplyStreamUpdate(stream: SettingsStream,
                                                new: SettingsStream,
                                                creating: Bool) -> Bool
    {
        guard isValidRemoteControlStreamUpdate(stream: stream,
                                               new: new,
                                               streams: database.streams,
                                               state: .init(isLive: isLive, isRecording: isRecording),
                                               creating: creating)
        else {
            return false
        }
        var effects = StreamUpdateEffects()
        stream.name = new.name
        effects.reload.apply(&stream.url, cleanUrl(url: new.url))
        effects.portrait = stream.portrait != new.portrait
        stream.portrait = new.portrait
        effects.pictureInPicture.apply(&stream.backgroundStreaming, new.backgroundStreaming)
        effects.pictureInPicture.apply(&stream.backgroundStreamingPiP, new.backgroundStreamingPiP)
        stream.autoGoLive = new.autoGoLive
        stream.estimatedViewerDelay = new.estimatedViewerDelay
        updateStreamObs(stream, new, &effects)
        effects.location.apply(&stream.realtimeIrlEnabled, new.realtimeIrlEnabled)
        effects.location.apply(&stream.realtimeIrlBaseUrl, new.realtimeIrlBaseUrl)
        effects.location.apply(&stream.realtimeIrlPushKey, new.realtimeIrlPushKey)
        effects.chats.apply(&stream.chat.bttvEmotes, new.chat.bttvEmotes)
        effects.chats.apply(&stream.chat.ffzEmotes, new.chat.ffzEmotes)
        effects.chats.apply(&stream.chat.seventvEmotes, new.chat.seventvEmotes)
        stream.goLiveNotificationDiscordMessage = new.goLiveNotificationDiscordMessage
        stream.goLiveNotificationDiscordWebhookUrl = cleanUrl(url: new.goLiveNotificationDiscordWebhookUrl)
        stream.goLiveNotificationMoblinWebsite = new.goLiveNotificationMoblinWebsite
        stream.discordSnapshotWebhook = cleanUrl(url: new.discordSnapshotWebhook)
        stream.discordChatBotSnapshotWebhook = cleanUrl(url: new.discordChatBotSnapshotWebhook)
        stream.discordSnapshotWebhookOnlyWhenLive = new.discordSnapshotWebhookOnlyWhenLive
        updateStreamVideo(stream, new, &effects)
        updateStreamSrt(stream.srt, new.srt, &effects)
        effects.reload.apply(&stream.rtmp.adaptiveBitrateEnabled, new.rtmp.adaptiveBitrateEnabled)
        effects.reload.apply(&stream.rist.adaptiveBitrateEnabled, new.rist.adaptiveBitrateEnabled)
        effects.reload.apply(&stream.rist.bonding, new.rist.bonding)
        effects.reload.apply(&stream.whip.headers, new.whip.headers)
        effects.reload.apply(&stream.whip.httpTransport, new.whip.httpTransport)
        updateStreamMultiStreaming(stream.multiStreaming, new.multiStreaming, &effects)
        updateStreamRecording(stream.recording, new.recording, &effects)
        stream.previewStream.url = cleanUrl(url: new.previewStream.url)
        stream.previewStream.resolution = new.previewStream.resolution
        stream.previewStream.bitrate = new.previewStream.bitrate
        updateStreamReplay(stream.replay, new.replay, &effects)
        updateStreamPlatforms(stream, new, &effects)
        guard !creating else {
            return true
        }
        applyStreamUpdateEffects(stream, effects)
        return true
    }

    private func updateStreamObs(_ stream: SettingsStream,
                                 _ new: SettingsStream,
                                 _ effects: inout StreamUpdateEffects)
    {
        effects.obsWebSocket.apply(&stream.obsWebSocketEnabled, new.obsWebSocketEnabled)
        effects.obsWebSocket.apply(&stream.obsWebSocketUrl, cleanUrl(url: new.obsWebSocketUrl))
        effects.obsWebSocket.apply(&stream.obsWebSocketPassword, new.obsWebSocketPassword)
        stream.obsSourceName = new.obsSourceName
        stream.obsMainScene = new.obsMainScene
        stream.obsBrbScene = new.obsBrbScene
        stream.obsBrbSceneVideoSourceBroken = new.obsBrbSceneVideoSourceBroken
        stream.obsAutoStartStream = new.obsAutoStartStream
        stream.obsAutoStopStream = new.obsAutoStopStream
        stream.obsAutoStartRecording = new.obsAutoStartRecording
        stream.obsAutoStopRecording = new.obsAutoStopRecording
        stream.streamingDirectlyToObs = new.streamingDirectlyToObs
    }

    private func updateStreamVideo(_ stream: SettingsStream,
                                   _ new: SettingsStream,
                                   _ effects: inout StreamUpdateEffects)
    {
        effects.reload.apply(&stream.resolution, new.resolution)
        effects.reload.apply(&stream.fps, new.fps)
        effects.lowLightBoost = stream.lowLightBoost != new.lowLightBoost
        stream.lowLightBoost = new.lowLightBoost
        effects.reload.apply(&stream.codec, new.codec)
        effects.reload.apply(&stream.h264Profile, new.h264Profile)
        effects.reload.apply(&stream.rateControl, SettingsStreamRateControl.makeValid(value: new.rateControl))
        effects.bitrate = stream.bitrate != new.bitrate
        stream.bitrate = new.bitrate
        effects.reload.apply(&stream.maxKeyFrameInterval, new.maxKeyFrameInterval)
        effects.reload.apply(&stream.bFrames, new.bFrames)
        effects.reload.apply(&stream.colorRange, new.colorRange)
        effects.reload.apply(&stream.adaptiveEncoderResolution, new.adaptiveEncoderResolution)
        effects.reload.apply(
            &stream.adaptiveEncoderResolutionThreashold,
            new.adaptiveEncoderResolutionThreashold
        )
        effects.timecodes.apply(&stream.timecodesEnabled, new.timecodesEnabled)
        effects.timecodes.apply(&stream.ntpPoolAddress, new.ntpPoolAddress)
        effects.reload.apply(&stream.audioCodec, new.audioCodec)
        effects.audioBitrate = stream.audioBitrate != new.audioBitrate
        stream.audioBitrate = new.audioBitrate
    }

    private func updateStreamSrt(_ srt: SettingsStreamSrt,
                                 _ newSrt: SettingsStreamSrt,
                                 _ effects: inout StreamUpdateEffects)
    {
        effects.reload.apply(&srt.latency, newSrt.latency)
        effects.reload.apply(&srt.adaptiveBitrateEnabled, newSrt.adaptiveBitrateEnabled)
        effects.reload.apply(&srt.maximumBandwidthFollowInput, newSrt.maximumBandwidthFollowInput)
        effects.reload.apply(&srt.overheadBandwidth, newSrt.overheadBandwidth)
        effects.reload.apply(&srt.bigPackets, newSrt.bigPackets)
        effects.reload.apply(&srt.implementation, newSrt.implementation)
        srt.dnsLookupStrategy = newSrt.dnsLookupStrategy
        let adaptiveBitrate = srt.adaptiveBitrate
        let newAdaptiveBitrate = newSrt.adaptiveBitrate
        effects.adaptiveBitrateAlgorithm = adaptiveBitrate.algorithm != newAdaptiveBitrate.algorithm
        effects.adaptiveBitrate.apply(&adaptiveBitrate.algorithm, newAdaptiveBitrate.algorithm)
        let fastIrl = adaptiveBitrate.fastIrlSettings
        let newFastIrl = newAdaptiveBitrate.fastIrlSettings
        effects.adaptiveBitrate.apply(&fastIrl.packetsInFlight, newFastIrl.packetsInFlight)
        effects.adaptiveBitrate.apply(&fastIrl.minimumBitrate, newFastIrl.minimumBitrate)
        let custom = adaptiveBitrate.customSettings
        let newCustom = newAdaptiveBitrate.customSettings
        effects.adaptiveBitrate.apply(&custom.packetsInFlight, newCustom.packetsInFlight)
        effects.adaptiveBitrate.apply(&custom.pifDiffIncreaseFactor, newCustom.pifDiffIncreaseFactor)
        effects.adaptiveBitrate.apply(&custom.rttDiffHighDecreaseFactor, newCustom.rttDiffHighDecreaseFactor)
        effects.adaptiveBitrate.apply(&custom.rttDiffHighAllowedSpike, newCustom.rttDiffHighAllowedSpike)
        effects.adaptiveBitrate.apply(
            &custom.rttDiffHighMinimumDecrease,
            newCustom.rttDiffHighMinimumDecrease
        )
        effects.adaptiveBitrate.apply(&custom.minimumBitrate, newCustom.minimumBitrate)
        effects.adaptiveBitrate.apply(&adaptiveBitrate.belaboxSettings.minimumBitrate,
                                      newAdaptiveBitrate.belaboxSettings.minimumBitrate)
        let connectionPriorities = srt.connectionPriorities
        let newConnectionPriorities = newSrt.connectionPriorities
        effects.connectionPriorities.apply(&connectionPriorities.enabled, newConnectionPriorities.enabled)
        let priorities = newConnectionPriorities.priorities.compactMap { newPriority in
            let priority = connectionPriorities.priorities.first { $0.id == newPriority.id }
            if let priority {
                effects.connectionPriorities.apply(&priority.priority, newPriority.priority)
                effects.connectionPriorities.apply(&priority.enabled, newPriority.enabled)
            }
            return priority
        }
        effects.connectionPriorities.applyItems(&connectionPriorities.priorities, priorities)
    }

    private func updateStreamMultiStreaming(_ multiStreaming: SettingsStreamMultiStreaming,
                                            _ newMultiStreaming: SettingsStreamMultiStreaming,
                                            _ effects: inout StreamUpdateEffects)
    {
        let destinations = newMultiStreaming.destinations.enumerated().map { index, newDestination in
            let destination = index < multiStreaming.destinations.count
                ? multiStreaming.destinations[index]
                : SettingsStreamMultiStreamingDestination()
            destination.name = newDestination.name
            effects.reload.apply(&destination.url, cleanUrl(url: newDestination.url))
            effects.reload.apply(&destination.enabled, newDestination.enabled)
            return destination
        }
        if destinations.count != multiStreaming.destinations.count {
            multiStreaming.destinations = destinations
        }
    }

    private func updateStreamRecording(_ recording: SettingsStreamRecording,
                                       _ newRecording: SettingsStreamRecording,
                                       _ effects: inout StreamUpdateEffects)
    {
        effects.reload.apply(&recording.overrideStream, newRecording.overrideStream)
        if recording.overrideStream {
            effects.reload.apply(&recording.resolution, newRecording.resolution)
        } else {
            recording.resolution = newRecording.resolution
        }
        recording.videoCodec = newRecording.videoCodec
        recording.videoBitrate = newRecording.videoBitrate
        recording.maxKeyFrameInterval = newRecording.maxKeyFrameInterval
        recording.audioBitrate = newRecording.audioBitrate
        recording.autoStartRecording = newRecording.autoStartRecording
        recording.autoStopRecording = newRecording.autoStopRecording
        effects.cleanRecordings = recording.cleanRecordings != newRecording.cleanRecordings
        recording.cleanRecordings = newRecording.cleanRecordings
        effects.cleanSnapshots = recording.cleanSnapshots != newRecording.cleanSnapshots
        recording.cleanSnapshots = newRecording.cleanSnapshots
    }

    private func updateStreamReplay(_ replay: SettingsStreamReplay,
                                    _ newReplay: SettingsStreamReplay,
                                    _ effects: inout StreamUpdateEffects)
    {
        effects.replayEnabled = replay.enabled != newReplay.enabled
        replay.enabled = newReplay.enabled
        replay.transitionType = newReplay.transitionType
        replay.inStinger.transitionPoint = newReplay.inStinger.transitionPoint
        replay.outStinger.transitionPoint = newReplay.outStinger.transitionPoint
        replay.postTriggerDelay = newReplay.postTriggerDelay
        var layout = replay.layout
        effects.replayLayout.apply(&layout.x, newReplay.layout.x)
        effects.replayLayout.apply(&layout.y, newReplay.layout.y)
        effects.replayLayout.apply(&layout.size, newReplay.layout.size)
        effects.replayLayout.apply(&layout.alignment, newReplay.layout.alignment)
        effects.replayLayout.apply(&layout.positioningLock, newReplay.layout.positioningLock)
        if effects.replayLayout.changed {
            layout.updateXString()
            layout.updateYString()
            layout.updateSizeString()
            replay.layout = layout
        }
    }

    private func updateStreamPlatforms(_ stream: SettingsStream,
                                       _ new: SettingsStream,
                                       _ effects: inout StreamUpdateEffects)
    {
        effects.twitchChannelName = stream.twitchChannelName != new.twitchChannelName
        stream.twitchChannelName = new.twitchChannelName
        effects.twitchChannelId = stream.twitchChannelId != new.twitchChannelId
        stream.twitchChannelId = new.twitchChannelId
        updateTwitchAlerts(stream.twitchChatAlerts, new.twitchChatAlerts)
        updateTwitchAlerts(stream.twitchToastAlerts, new.twitchToastAlerts)
        if stream.kickChannelName != new.kickChannelName {
            effects.kickChannelName = true
            stream.kickChannelName = new.kickChannelName
            stream.kickChannelId = nil
            stream.kickSlug = nil
            stream.kickChatroomChannelId = nil
        }
        updateKickAlerts(stream.kickChatAlerts, new.kickChatAlerts)
        updateKickAlerts(stream.kickToastAlerts, new.kickToastAlerts)
        let youTubeVideoIds = new.youTubeVideoIds.removeAllWhitespaces()
        effects.youTubeVideoIds = stream.youTubeVideoIds != youTubeVideoIds
        stream.youTubeVideoIds = youTubeVideoIds
        stream.youTubeHandle = new.youTubeHandle
        stream.youTubeScheduleStreamTitle = new.youTubeScheduleStreamTitle
        stream.youTubeScheduleStreamVisibility = new.youTubeScheduleStreamVisibility
        stream.youTubeScheduleStreamAutoStop = new.youTubeScheduleStreamAutoStop
        effects.soopChannelName = stream.soopChannelName != new.soopChannelName
        stream.soopChannelName = new.soopChannelName
        effects.soopStreamId = stream.soopStreamId != new.soopStreamId
        stream.soopStreamId = new.soopStreamId
        effects.openStreamingPlatformUrl = stream.openStreamingPlatformUrl != new.openStreamingPlatformUrl
        stream.openStreamingPlatformUrl = new.openStreamingPlatformUrl
        effects.openStreamingPlatformChannelId = stream.openStreamingPlatformChannelId != new
            .openStreamingPlatformChannelId
        stream.openStreamingPlatformChannelId = new.openStreamingPlatformChannelId
    }

    private func updateTwitchAlerts(_ alerts: SettingsTwitchAlerts, _ newAlerts: SettingsTwitchAlerts) {
        alerts.follows = newAlerts.follows
        alerts.subscriptions = newAlerts.subscriptions
        alerts.giftSubscriptions = newAlerts.giftSubscriptions
        alerts.resubscriptions = newAlerts.resubscriptions
        alerts.rewards = newAlerts.rewards
        alerts.raids = newAlerts.raids
        alerts.cheers = newAlerts.cheers
        alerts.minimumCheerBits = newAlerts.minimumCheerBits
        alerts.watchStreaks = newAlerts.watchStreaks
        alerts.minimumWatchStreak = newAlerts.minimumWatchStreak
        alerts.sharedChat = newAlerts.sharedChat
    }

    private func updateKickAlerts(_ alerts: SettingsKickAlerts, _ newAlerts: SettingsKickAlerts) {
        alerts.subscriptions = newAlerts.subscriptions
        alerts.giftedSubscriptions = newAlerts.giftedSubscriptions
        alerts.rewards = newAlerts.rewards
        alerts.hosts = newAlerts.hosts
        alerts.bans = newAlerts.bans
        alerts.kicks = newAlerts.kicks
        alerts.minimumKicks = newAlerts.minimumKicks
    }

    private func applyStreamUpdateEffects(_ stream: SettingsStream, _ effects: StreamUpdateEffects) {
        if effects.connectionPriorities.changed {
            updateSrtlaPriorities()
            objectWillChange.send()
        }
        if effects.lowLightBoost {
            setStreamFps()
        }
        if effects.cleanRecordings {
            setCleanRecordings()
        }
        if effects.cleanSnapshots {
            setCleanSnapshots()
        }
        if effects.replayLayout.changed {
            replayEffect?.setLayout(layout: stream.replay.layout)
        }
        if effects.kickChannelName {
            remoteControlFetchKickChannelInfo(stream: stream)
        }
        guard stream.enabled else {
            return
        }
        if effects.pictureInPicture.changed {
            updatePictureInPicture()
        }
        if effects.obsWebSocket.changed {
            obsWebSocketEnabledUpdated()
        }
        if effects.location.changed {
            reloadLocation()
        }
        if effects.chats.changed {
            reloadChats()
        }
        if effects.bitrate {
            setStreamBitrate(stream: stream)
        }
        if effects.audioBitrate {
            setAudioStreamBitrate(stream: stream)
        }
        if effects.timecodes.changed {
            reloadNtpClient()
            reloadIngests()
        }
        if effects.adaptiveBitrateAlgorithm, stream.srt.adaptiveBitrateEnabled {
            setAdaptiveBitrateSrtAlgorithm(stream: stream)
        }
        if effects.adaptiveBitrate.changed {
            updateAdaptiveBitrateSrt(srt: stream.srt)
        }
        if effects.replayEnabled {
            streamReplayEnabledUpdated()
        }
        if effects.twitchChannelName {
            twitchChannelNameUpdated()
        }
        if effects.twitchChannelId {
            twitchChannelIdUpdated()
        }
        if effects.kickChannelName, stream.kickChannelName.isEmpty {
            kickChannelNameUpdated()
        }
        if effects.youTubeVideoIds {
            youTubeVideoIdUpdated()
        }
        if effects.soopChannelName {
            soopChannelNameUpdated()
        }
        if effects.soopStreamId {
            soopStreamIdUpdated()
        }
        if effects.openStreamingPlatformUrl {
            openStreamingPlatformUrlUpdated()
        }
        if effects.openStreamingPlatformChannelId {
            openStreamingPlatformRoomUpdated()
        }
        if effects.portrait {
            setCurrentStream(stream: stream)
            reloadStream()
            resetSelectedScene(changeScene: false)
            updateOrientation()
            updateOrientationLock()
        } else if effects.reload.changed {
            reloadStreamIfEnabled(stream: stream)
        }
    }

    private func remoteControlFetchKickChannelInfo(stream: SettingsStream) {
        let channelName = stream.kickChannelName
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard stream.kickChannelName == channelName else {
                return
            }
            if let channelInfo {
                stream.kickChannelId = String(channelInfo.chatroom.id)
                stream.kickSlug = channelInfo.slug
                stream.kickChatroomChannelId = String(channelInfo.chatroom.channel_id)
            }
            if stream.enabled {
                self.kickAccessTokenUpdated()
            }
        }
    }
}
