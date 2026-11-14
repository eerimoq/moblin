import Foundation

struct RemoteControlStreamState {
    var isLive = false
    var isRecording = false
}

private struct StreamLocks {
    let live: Bool
    let recording: Bool
    let liveOrRecording: Bool
}

private func isValidChange<T: Equatable>(_ old: T,
                                         _ new: T,
                                         disabled: Bool = false,
                                         _ isValid: (T) -> Bool = { _ in true }) -> Bool
{
    old == new || !disabled && isValid(new)
}

func isValidRemoteControlStreamUpdate(stream: SettingsStream,
                                      new: SettingsStream,
                                      streams: [SettingsStream],
                                      state: RemoteControlStreamState,
                                      creating: Bool) -> Bool
{
    let locks = StreamLocks(live: stream.enabled && state.isLive,
                            recording: stream.enabled && state.isRecording,
                            liveOrRecording: stream.enabled && (state.isLive || state.isRecording))
    return isValidStreamName(stream, new, streams, creating)
        && isValidChange(stream.url,
                         cleanUrl(url: new.url),
                         disabled: !creating && (state.isLive || state.isRecording))
        {
            isValidUrl(url: $0) == nil
        }
        && isValidChange(stream.portrait, new.portrait, disabled: locks.liveOrRecording)
        && isValidChange(stream.estimatedViewerDelay, new.estimatedViewerDelay) { (0 ... 15).contains($0) }
        && isValidChange(stream.realtimeIrlBaseUrl, new.realtimeIrlBaseUrl) { isValidHttpUrl(url: $0) == nil }
        && isValidChange(stream.obsWebSocketUrl, cleanUrl(url: new.obsWebSocketUrl)) {
            isValidWebSocketUrl(url: $0) == nil
        }
        && isValidChange(stream.openStreamingPlatformUrl, new.openStreamingPlatformUrl) {
            isValidWebSocketUrl(url: $0) == nil
        }
        && isValidChange(stream.obsBrbSceneVideoSourceBroken,
                         new.obsBrbSceneVideoSourceBroken,
                         disabled: new.obsBrbScene.isEmpty)
        && isValidTwitchAlertsUpdate(stream.twitchChatAlerts, new.twitchChatAlerts)
        && isValidTwitchAlertsUpdate(stream.twitchToastAlerts, new.twitchToastAlerts)
        && isValidVideoUpdate(stream, new, locks)
        && isValidChange(stream.audioCodec, new.audioCodec, disabled: locks.live)
        && isValidChange(stream.audioBitrate, new.audioBitrate, disabled: locks.live) {
            SettingsStream.isValidAudioBitrate(bitrate: $0)
        }
        && isValidSrtUpdate(stream.srt, new.srt, locks)
        && isValidChange(
            stream.rtmp.adaptiveBitrateEnabled,
            new.rtmp.adaptiveBitrateEnabled,
            disabled: locks.live
        )
        && isValidChange(
            stream.rist.adaptiveBitrateEnabled,
            new.rist.adaptiveBitrateEnabled,
            disabled: locks.live
        )
        && isValidChange(stream.rist.bonding, new.rist.bonding, disabled: locks.live)
        && isValidWhipUpdate(stream.whip, new.whip, locks)
        && isValidMultiStreamingUpdate(stream.multiStreaming, new.multiStreaming, locks)
        && isValidRecordingUpdate(stream.recording, new.recording, locks)
        && isValidPreviewStreamUpdate(stream.previewStream, new.previewStream)
        && isValidReplayUpdate(stream.replay, new.replay)
}

private func isValidStreamName(_ stream: SettingsStream,
                               _ new: SettingsStream,
                               _ streams: [SettingsStream],
                               _ creating: Bool) -> Bool
{
    if !creating, stream.name == new.name {
        return true
    }
    return !new.name.isEmpty && !streams.contains { $0.id != new.id && $0.name == new.name }
}

private func isValidTwitchAlertsUpdate(_ alerts: SettingsTwitchAlerts,
                                       _ newAlerts: SettingsTwitchAlerts) -> Bool
{
    isValidChange(alerts.minimumWatchStreak, newAlerts.minimumWatchStreak) {
        [1, 3, 5, 10, 15, 20, 25].contains($0)
    }
}

private func isValidVideoUpdate(_ stream: SettingsStream, _ new: SettingsStream,
                                _ locks: StreamLocks) -> Bool
{
    isValidChange(stream.resolution, new.resolution, disabled: locks.liveOrRecording)
        && isValidChange(stream.fps, new.fps, disabled: locks.liveOrRecording) { fpss.contains($0) }
        && isValidChange(stream.codec, new.codec, disabled: locks.live)
        && isValidChange(stream.h264Profile, new.h264Profile, disabled: locks.live)
        && isValidChange(stream.rateControl, new.rateControl, disabled: locks.live)
        && isValidChange(stream.bitrate, new.bitrate) { SettingsStream.isValidBitrate(bitrate: $0) }
        && isValidChange(stream.maxKeyFrameInterval, new.maxKeyFrameInterval, disabled: locks.live) {
            SettingsStream.isValidMaxKeyFrameInterval(interval: $0)
        }
        && isValidChange(stream.bFrames, new.bFrames, disabled: locks.live)
        && isValidChange(stream.colorRange, new.colorRange, disabled: locks.liveOrRecording)
        && isValidChange(
            stream.adaptiveEncoderResolution,
            new.adaptiveEncoderResolution,
            disabled: locks.live
        )
        && isValidChange(stream.adaptiveEncoderResolutionThreashold,
                         new.adaptiveEncoderResolutionThreashold,
                         disabled: locks.live) { (1 ... 3).contains($0) }
        && isValidChange(stream.timecodesEnabled,
                         new.timecodesEnabled,
                         disabled: ![.srt, .rist].contains(new.getProtocol())
                             || new.codec != .h265hevc
                             || locks.live)
        && isValidChange(stream.ntpPoolAddress,
                         new.ntpPoolAddress,
                         disabled: new.codec != .h265hevc || locks.live)
}

private func isValidSrtUpdate(_ srt: SettingsStreamSrt, _ newSrt: SettingsStreamSrt,
                              _ locks: StreamLocks) -> Bool
{
    isValidChange(srt.latency, newSrt.latency, disabled: locks.live) {
        SettingsStreamSrt.isValidLatency(latency: $0)
    }
        && isValidChange(srt.adaptiveBitrateEnabled, newSrt.adaptiveBitrateEnabled, disabled: locks.live)
        && isValidChange(srt.maximumBandwidthFollowInput,
                         newSrt.maximumBandwidthFollowInput,
                         disabled: locks.live)
        && isValidChange(srt.overheadBandwidth, newSrt.overheadBandwidth, disabled: locks.live) {
            (5 ... 100).contains($0)
        }
        && isValidChange(srt.bigPackets, newSrt.bigPackets, disabled: locks.live)
        && isValidChange(srt.dnsLookupStrategy, newSrt.dnsLookupStrategy, disabled: locks.live)
        && isValidChange(srt.implementation, newSrt.implementation, disabled: locks.live)
        && isValidSrtAdaptiveBitrateUpdate(srt.adaptiveBitrate, newSrt.adaptiveBitrate)
        && isValidConnectionPrioritiesUpdate(srt.connectionPriorities, newSrt.connectionPriorities)
}

private func isValidSrtAdaptiveBitrateUpdate(_ adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate,
                                             _ newAdaptiveBitrate: SettingsStreamSrtAdaptiveBitrate) -> Bool
{
    let fastIrl = adaptiveBitrate.fastIrlSettings
    let newFastIrl = newAdaptiveBitrate.fastIrlSettings
    let custom = adaptiveBitrate.customSettings
    let newCustom = newAdaptiveBitrate.customSettings
    let isValidMinimumBitrate = { (bitrate: Float) in (50 ... 2000).contains(bitrate) }
    return isValidChange(fastIrl.packetsInFlight, newFastIrl.packetsInFlight) { (200 ... 700).contains($0) }
        && isValidChange(fastIrl.minimumBitrate, newFastIrl.minimumBitrate, isValidMinimumBitrate)
        &&
        isValidChange(custom.pifDiffIncreaseFactor, newCustom.pifDiffIncreaseFactor) {
            (5 ... 500).contains($0)
        }
        && isValidChange(custom.rttDiffHighDecreaseFactor, newCustom.rttDiffHighDecreaseFactor) {
            (0.87 ... 0.98).contains($0)
        }
        && isValidChange(custom.rttDiffHighMinimumDecrease, newCustom.rttDiffHighMinimumDecrease) {
            (5 ... 400).contains($0)
        }
        && isValidChange(custom.packetsInFlight, newCustom.packetsInFlight) { (50 ... 5000).contains($0) }
        && isValidChange(custom.rttDiffHighAllowedSpike, newCustom.rttDiffHighAllowedSpike) {
            (25 ... 1000).contains($0)
        }
        && isValidChange(custom.minimumBitrate, newCustom.minimumBitrate, isValidMinimumBitrate)
        && isValidChange(adaptiveBitrate.belaboxSettings.minimumBitrate,
                         newAdaptiveBitrate.belaboxSettings.minimumBitrate,
                         isValidMinimumBitrate)
}

private func isValidConnectionPrioritiesUpdate(_ priorities: SettingsStreamSrtConnectionPriorities,
                                               _ newPriorities: SettingsStreamSrtConnectionPriorities) -> Bool
{
    guard hasUniqueRemoteControlIds(newPriorities.priorities) else {
        return false
    }
    return newPriorities.priorities.allSatisfy { newPriority in
        guard let priority = priorities.priorities.first(where: { $0.id == newPriority.id }) else {
            return false
        }
        return isValidChange(priority.priority, newPriority.priority) {
            (minimumSrtConnectionPriority ... maximumSrtConnectionPriority).contains($0)
        }
    }
        && priorities.priorities.allSatisfy { priority in
            !["Cellular", "WiFi"].contains(priority.name)
                || newPriorities.priorities.contains { $0.id == priority.id }
        }
}

private func isValidWhipUpdate(_ whip: SettingsStreamWhip,
                               _ newWhip: SettingsStreamWhip,
                               _ locks: StreamLocks) -> Bool
{
    let headers = whip.headers.map { [$0.name, $0.value] }
    let newHeaders = newWhip.headers.map { [$0.name, $0.value] }
    let isAuthorization = { (header: [String]) in header[0] == "Authorization" }
    return isValidChange(headers, newHeaders, disabled: locks.live) { newHeaders in
        newHeaders.filter { !isAuthorization($0) } == headers.filter { !isAuthorization($0) }
            && newHeaders.filter(isAuthorization).count <= max(headers.filter(isAuthorization).count, 1)
            && newHeaders.filter(isAuthorization).allSatisfy { header in
                headers.contains(header) || header[1].hasPrefix("Bearer ")
            }
    }
        && isValidChange(whip.httpTransport, newWhip.httpTransport, disabled: locks.live)
}

private func isValidMultiStreamingUpdate(_ multiStreaming: SettingsStreamMultiStreaming,
                                         _ newMultiStreaming: SettingsStreamMultiStreaming,
                                         _ locks: StreamLocks) -> Bool
{
    let destinations = multiStreaming.destinations
    let newDestinations = newMultiStreaming.destinations
    guard !locks.liveOrRecording || newDestinations.count == destinations.count else {
        return false
    }
    return newDestinations.enumerated().allSatisfy { index, newDestination in
        let destination = index < destinations.count ? destinations[index] : nil
        return isValidChange(destination?.name ?? "", newDestination.name) { name in
            !name.isEmpty && newDestinations.count(where: { $0.name == name }) == 1
        }
            && isValidChange(destination?.url ?? defaultRtmpStreamUrl,
                             cleanUrl(url: newDestination.url),
                             disabled: locks.liveOrRecording)
            {
                isValidUrl(url: $0, allowedSchemes: ["rtmp", "rtmps"]) == nil
            }
            && isValidChange(destination?.enabled ?? false,
                             newDestination.enabled,
                             disabled: locks.liveOrRecording)
    }
}

private func isValidRecordingUpdate(_ recording: SettingsStreamRecording,
                                    _ newRecording: SettingsStreamRecording,
                                    _ locks: StreamLocks) -> Bool
{
    isValidChange(recording.overrideStream, newRecording.overrideStream, disabled: locks.liveOrRecording)
        && isValidChange(recording.resolution, newRecording.resolution, disabled: locks.liveOrRecording)
        && isValidChange(recording.videoCodec, newRecording.videoCodec, disabled: locks.recording)
        && isValidChange(recording.videoBitrate, newRecording.videoBitrate, disabled: locks.recording) {
            $0 <= 50_000_000
        }
        && isValidChange(recording.maxKeyFrameInterval,
                         newRecording.maxKeyFrameInterval,
                         disabled: locks.recording)
        { SettingsStream.isValidMaxKeyFrameInterval(interval: $0)
        }
        && isValidChange(recording.audioBitrate, newRecording.audioBitrate, disabled: locks.recording) {
            $0 <= 320_000 && $0 % 32000 == 0
        }
}

private func isValidPreviewStreamUpdate(_ previewStream: SettingsStreamPreviewStream,
                                        _ newPreviewStream: SettingsStreamPreviewStream) -> Bool
{
    isValidChange(previewStream.url, cleanUrl(url: newPreviewStream.url)) {
        $0.isEmpty || isValidUrl(url: $0, allowedSchemes: ["whip", "whips"]) == nil
    }
        && isValidChange(previewStream.resolution, newPreviewStream.resolution) {
            [.r854x480, .r640x360, .r426x240].contains($0)
        }
        && isValidChange(previewStream.bitrate, newPreviewStream.bitrate) {
            [2_000_000, 1_500_000, 1_000_000, 500_000, 250_000].contains($0)
        }
}

private func isValidReplayUpdate(_ replay: SettingsStreamReplay, _ newReplay: SettingsStreamReplay) -> Bool {
    isValidChange(replay.postTriggerDelay, newReplay.postTriggerDelay) { (2 ... 5).contains($0) }
        && isValidChange(replay.layout.x, newReplay.layout.x) { (0 ... 100).contains($0) }
        && isValidChange(replay.layout.y, newReplay.layout.y) { (0 ... 100).contains($0) }
        && isValidChange(replay.layout.size, newReplay.layout.size) { (1 ... 100).contains($0) }
        && isValidChange(replay.inStinger.transitionPoint, newReplay.inStinger.transitionPoint) {
            (0 ... 1).contains($0)
        }
        && isValidChange(replay.outStinger.transitionPoint, newReplay.outStinger.transitionPoint) {
            (0 ... 1).contains($0)
        }
}
