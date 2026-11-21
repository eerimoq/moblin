import Foundation

extension Model {
    func updateAudioMixer() {
        setAudioChannelsMap(channelsMap: makeAudioEncoderChannelsMap())
        updateAudioGain()
        updateMicDelay()
        if !database.debug.audioMixer {
            media.setMixedAudio(sources: nil)
        }
    }

    func updateMixedMics() {
        guard database.debug.audioMixer else {
            return
        }
        let current = getMicById(id: mic.current.id) ?? mic.current
        media.setMixedAudio(sources: [makeAudioMixerSourceSettings(mic: current)])
    }

    private func makeAudioMixerSourceSettings(mic: SettingsMicsMic) -> AudioMixerSourceSettings {
        AudioMixerSourceSettings(id: mic.id,
                                 bufferedAudio: getMicCameraId(mic: mic),
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
