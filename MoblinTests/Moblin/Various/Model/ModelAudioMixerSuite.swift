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

    @Test(arguments: [
        MixableCase(mic: srtlaMic, current: frontMic, expected: true),
        MixableCase(mic: mediaPlayerMic, current: usbMic, expected: true),
        MixableCase(mic: screenCaptureMic, current: srtlaMic, expected: true),
        MixableCase(mic: rtmpMic, current: srtlaMic, expected: true),
        MixableCase(mic: frontMic, current: srtlaMic, expected: false),
        MixableCase(mic: usbMic, current: frontMic, expected: false),
        MixableCase(mic: backMic, current: frontMic, expected: false),
        MixableCase(mic: srtlaMic, current: srtlaMic, expected: false),
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
}
