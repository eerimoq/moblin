import Foundation
@testable import Moblin
import Testing

struct SettingsGameControllerSuite {
    @Test
    func playSoundButtonSurvivesEncodeAndDecode() throws {
        let soundId = UUID()
        let button = SettingsGameControllerButton()
        button.function = .playSound
        button.functionData.soundId = soundId
        let decoded = try JSONDecoder().decode(SettingsGameControllerButton.self,
                                               from: JSONEncoder().encode(button))
        #expect(decoded.function == .playSound)
        #expect(decoded.functionData.soundId == soundId)
    }

    @Test
    func playSoundButtonDefaultsWhenMissingFromSettings() throws {
        let button = try JSONDecoder().decode(SettingsGameControllerButton.self, from: Data("{}".utf8))
        #expect(button.functionData.soundId == nil)
    }

    @Test
    func playSoundGimbalButtonsSurviveEncodeAndDecode() throws {
        let shutterSoundId = UUID()
        let flipSoundId = UUID()
        let gimbal = SettingsGimbal()
        gimbal.functionShutter = .playSound
        gimbal.functionDataShutter.soundId = shutterSoundId
        gimbal.functionFlip = .playSound
        gimbal.functionDataFlip.soundId = flipSoundId
        let decoded = try JSONDecoder().decode(SettingsGimbal.self, from: JSONEncoder().encode(gimbal))
        #expect(decoded.functionDataShutter.soundId == shutterSoundId)
        #expect(decoded.functionDataFlip.soundId == flipSoundId)
    }
}
