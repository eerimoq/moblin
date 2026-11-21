import Foundation

func isAudioMicMixable(mic: SettingsMicsMic, current: SettingsMicsMic) -> Bool {
    guard mic != current else {
        return false
    }
    guard mic.isAudioSession() else {
        return true
    }
    return mic.channel != nil && current.channel != nil && mic.inputUid == current.inputUid
}

func makeAudioChannelMicNames(portName: String, channelNames: [String?]) -> [String] {
    let names = channelNames.enumerated().map { channel, channelName in
        guard let channelName, !channelName.isEmpty, channelName != portName else {
            return "\(portName) \(channel + 1)"
        }
        if channelName.hasPrefix(portName) {
            return channelName
        }
        return "\(portName): \(channelName)"
    }
    guard Set(names).count == names.count else {
        return channelNames.indices.map { "\(portName) \($0 + 1)" }
    }
    return names
}

func makeAudioMixerMixedMics(mics: [SettingsMicsMic], current: SettingsMicsMic) -> [SettingsMicsMic] {
    mics.filter { $0.mixed && $0.connected && isAudioMicMixable(mic: $0, current: current) }
}

func isAudioChannelMicConnected(mic: SettingsMicsMic,
                                found: [SettingsMicsMic],
                                inputUid: String?,
                                numberOfChannels: Int) -> Bool
{
    guard let channel = mic.channel, found.contains(where: { $0.inputUid == mic.inputUid }) else {
        return false
    }
    return mic.inputUid != inputUid || channel < numberOfChannels
}

func makeMicDelayRange(audioMixer: Bool) -> ClosedRange<Double> {
    audioMixer ? -0.5 ... 2.0 : -0.5 ... 0.5
}

extension Model {
    func updateAudioMixer() {
        setAudioChannelsMap(channelsMap: makeAudioEncoderChannelsMap())
        updateAudioGain()
        updateMicDelay()
        if !database.debug.audioMixer {
            media.setMixedAudio(sources: nil)
            mic.mixed = []
            if mic.current.channel != nil,
               let deviceMic = database.mics.mics.first(where: {
                   $0.inputUid == mic.current.inputUid && $0.channel == nil
               })
            {
                manualSelectMicById(id: deviceMic.id)
            }
        }
    }

    func isMicMixable(mic: SettingsMicsMic) -> Bool {
        database.debug.audioMixer && isAudioMicMixable(mic: mic, current: self.mic.current)
    }

    func setMicMixed(mic: SettingsMicsMic, mixed: Bool) {
        mic.mixed = mixed
        updateMixedMics()
    }

    func updateMixedMics() {
        guard database.debug.audioMixer else {
            return
        }
        let current = getMicById(id: mic.current.id) ?? mic.current
        var mixedMics: [SettingsMicsMic] = []
        if !isChatPhone() {
            mixedMics = makeAudioMixerMixedMics(mics: database.mics.mics, current: current)
        }
        if mixedMics != mic.mixed {
            mic.mixed = mixedMics
        }
        let sources = ([current] + mixedMics).compactMap { makeAudioMixerSourceSettings(mic: $0) }
        media.setMixedAudio(sources: sources)
    }

    private func makeAudioMixerSourceSettings(mic: SettingsMicsMic) -> AudioMixerSourceSettings? {
        let bufferedAudio = getMicCameraId(mic: mic)
        guard bufferedAudio != nil || mic.isAudioSession() else {
            return nil
        }
        return AudioMixerSourceSettings(id: mic.id,
                                        bufferedAudio: bufferedAudio,
                                        channelsMap: makeAudioInputChannelsMap(),
                                        channel: mic.channel,
                                        gain: pow(10, mic.gainDb / 20),
                                        delay: mic.delay.clamped(to: makeMicDelayRange(audioMixer: true)))
    }

    private func makeAudioEncoderChannelsMap() -> [Int: Int] {
        if database.debug.audioMixer {
            [0: 0, 1: 1]
        } else {
            makeAudioInputChannelsMap()
        }
    }

    private func makeAudioInputChannelsMap() -> [Int: Int] {
        [
            0: database.audio.outputToInputChannelsMap.channel1,
            1: database.audio.outputToInputChannelsMap.channel2,
        ]
    }
}
