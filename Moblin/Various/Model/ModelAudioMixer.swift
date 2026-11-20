import Foundation

func isAudioMicMixable(mic: SettingsMicsMic, current: SettingsMicsMic) -> Bool {
    mic != current && !mic.isAudioSession()
}

func makeAudioMixerMixedMics(mics: [SettingsMicsMic], current: SettingsMicsMic) -> [SettingsMicsMic] {
    mics.filter { $0.mixed && $0.connected && isAudioMicMixable(mic: $0, current: current) }
}

extension Model {
    func updateAudioMixer() {
        setAudioChannelsMap(channelsMap: makeAudioEncoderChannelsMap())
        updateAudioGain()
        updateMicDelay()
        if !database.debug.audioMixer {
            media.setMixedAudio(sources: nil)
            mic.mixed = []
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
                                        gain: pow(10, mic.gainDb / 20),
                                        delay: mic.delay.clamped(to: -0.5 ... 0.5))
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
