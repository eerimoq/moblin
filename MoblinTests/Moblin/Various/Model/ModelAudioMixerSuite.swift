import Foundation
@testable import Moblin
import Testing

private func createBuiltinMic(_ orientation: SettingsMic, _ dataSourceId: Int) -> SettingsMicsMic {
    let mic = SettingsMicsMic(
        name: orientation.rawValue,
        inputUid: "BuiltInMicrophoneDevice",
        connected: true
    )
    mic.dataSourceId = dataSourceId
    mic.builtInOrientation = orientation
    return mic
}

private func createChannelMic(_ mic: SettingsMicsMic, _ channel: Int) -> SettingsMicsMic {
    let channelMic = SettingsMicsMic(
        name: "\(mic.name) \(channel + 1)",
        inputUid: mic.inputUid,
        connected: true
    )
    channelMic.channel = channel
    return channelMic
}

private func createMixedMic(_ mic: SettingsMicsMic) -> SettingsMicsMic {
    let mixedMic = SettingsMicsMic(name: mic.name, inputUid: mic.inputUid, connected: mic.connected)
    mixedMic.dataSourceId = mic.dataSourceId
    mixedMic.builtInOrientation = mic.builtInOrientation
    mixedMic.mixed = true
    return mixedMic
}

private let frontMic = createBuiltinMic(.front, 1)
private let backMic = createBuiltinMic(.back, 2)
private let usbMic = SettingsMicsMic(name: "USB Audio", inputUid: "AppleUSBAudioEngine:1", connected: true)
private let usbMic1 = createChannelMic(usbMic, 0)
private let usbMic2 = createChannelMic(usbMic, 1)
private let interfaceMic1 = createChannelMic(
    SettingsMicsMic(name: "Interface", inputUid: "AppleUSBAudioEngine:2", connected: true),
    0
)
private let srtlaMic = SettingsMicsMic(name: srtlaCamera(name: "Cam 2"),
                                       inputUid: UUID().uuidString,
                                       connected: true)
private let rtmpMic = SettingsMicsMic(name: rtmpCamera(name: "Cam 3"),
                                      inputUid: UUID().uuidString,
                                      connected: false)
private let mediaPlayerMic = SettingsMicsMic(name: mediaPlayerCamera(name: "Music"),
                                             inputUid: UUID().uuidString,
                                             connected: true)
private let screenCaptureMic = SettingsMicsMic(name: screenCaptureCameraName,
                                               inputUid: screenCaptureCameraId.uuidString,
                                               connected: true)

struct ModelAudioMixerSuite {
    struct MixableCase: CustomTestStringConvertible {
        let mic: SettingsMicsMic
        let current: SettingsMicsMic
        let expected: Bool

        var testDescription: String {
            "\(mic.name) into \(current.name)"
        }
    }

    struct MixedMicsCase: CustomTestStringConvertible {
        let testDescription: String
        let mics: [SettingsMicsMic]
        let current: SettingsMicsMic
        let expected: [SettingsMicsMic]
    }

    struct ChannelMicCase: CustomTestStringConvertible {
        let testDescription: String
        let inputUid: String
        let numberOfChannels: Int
        let expected: Bool
    }

    @Test(arguments: [
        MixableCase(mic: srtlaMic, current: frontMic, expected: true),
        MixableCase(mic: mediaPlayerMic, current: usbMic, expected: true),
        MixableCase(mic: screenCaptureMic, current: srtlaMic, expected: true),
        MixableCase(mic: rtmpMic, current: srtlaMic, expected: true),
        MixableCase(mic: frontMic, current: srtlaMic, expected: false),
        MixableCase(mic: usbMic, current: frontMic, expected: false),
        MixableCase(mic: backMic, current: frontMic, expected: false),
        MixableCase(mic: srtlaMic, current: srtlaMic, expected: false),
        MixableCase(mic: usbMic2, current: usbMic1, expected: true),
        MixableCase(mic: srtlaMic, current: usbMic1, expected: true),
        MixableCase(mic: usbMic1, current: usbMic, expected: false),
        MixableCase(mic: usbMic, current: usbMic1, expected: false),
        MixableCase(mic: interfaceMic1, current: usbMic1, expected: false),
    ])
    func mixable(_ testCase: MixableCase) {
        #expect(isAudioMicMixable(mic: testCase.mic, current: testCase.current) == testCase.expected)
    }

    @Test(arguments: [
        MixedMicsCase(testDescription: "Only mixed mics",
                      mics: [srtlaMic, createMixedMic(mediaPlayerMic), frontMic],
                      current: frontMic,
                      expected: [mediaPlayerMic]),
        MixedMicsCase(testDescription: "Disconnected mixed mic",
                      mics: [createMixedMic(srtlaMic), createMixedMic(rtmpMic), frontMic],
                      current: frontMic,
                      expected: [srtlaMic]),
        MixedMicsCase(testDescription: "Mixed current mic",
                      mics: [createMixedMic(srtlaMic), createMixedMic(mediaPlayerMic)],
                      current: srtlaMic,
                      expected: [mediaPlayerMic]),
        MixedMicsCase(testDescription: "Mixed built-in and external mics",
                      mics: [
                          createMixedMic(backMic),
                          createMixedMic(usbMic),
                          createMixedMic(screenCaptureMic),
                      ],
                      current: srtlaMic,
                      expected: [screenCaptureMic]),
        MixedMicsCase(testDescription: "List order",
                      mics: [
                          createMixedMic(screenCaptureMic),
                          createMixedMic(mediaPlayerMic),
                          createMixedMic(srtlaMic),
                      ],
                      current: frontMic,
                      expected: [screenCaptureMic, mediaPlayerMic, srtlaMic]),
    ])
    func mixedMics(_ testCase: MixedMicsCase) {
        #expect(makeAudioMixerMixedMics(mics: testCase.mics, current: testCase.current) == testCase.expected)
    }

    @Test(arguments: [
        ChannelMicCase(testDescription: "Delivered channel",
                       inputUid: usbMic.inputUid,
                       numberOfChannels: 2,
                       expected: true),
        ChannelMicCase(testDescription: "Channel above the delivered count",
                       inputUid: usbMic.inputUid,
                       numberOfChannels: 1,
                       expected: false),
        ChannelMicCase(testDescription: "Count delivered by another device",
                       inputUid: frontMic.inputUid,
                       numberOfChannels: 1,
                       expected: true),
    ])
    func channelMicConnected(_ testCase: ChannelMicCase) {
        #expect(isAudioChannelMicConnected(mic: usbMic2,
                                           found: [frontMic, usbMic],
                                           inputUid: testCase.inputUid,
                                           numberOfChannels: testCase.numberOfChannels) == testCase.expected)
    }

    @Test
    func channelMicNames() {
        let makeNames = { (channelNames: [String?]) in
            makeAudioChannelMicNames(portName: "Wireless microphone", channelNames: channelNames)
        }
        #expect(makeNames(["Wireless microphone 1", "Wireless microphone 2"])
            == ["Wireless microphone 1", "Wireless microphone 2"])
        #expect(makeNames(["Left", "Right"]) == ["Wireless microphone: Left", "Wireless microphone: Right"])
        #expect(makeNames(["", nil]) == ["Wireless microphone 1", "Wireless microphone 2"])
        #expect(makeNames(["Wireless microphone", "Wireless microphone"])
            == ["Wireless microphone 1", "Wireless microphone 2"])
        #expect(makeNames(["Mic", "Mic"]) == ["Wireless microphone 1", "Wireless microphone 2"])
    }
}
