import Foundation
@testable import Moblin
import Testing
import VideoToolbox

struct VideoEncoderSettingsSuite {
    @Test
    func defaultExpectedFrameRate() {
        #expect(VideoEncoderSettings().expectedFrameRate == 30)
    }

    @Test(arguments: [25.0, 30.0, 50.0, 60.0])
    func expectedFrameRate(fps: Double) throws {
        let original = VideoEncoderSettings()
        var settings = original
        settings.expectedFrameRate = fps
        let property = try #require(settings.properties().first {
            $0.key.value == kVTCompressionPropertyKey_ExpectedFrameRate
        })
        #expect((property.value as? NSNumber)?.doubleValue == fps)
        #expect(settings.shouldInvalidateSession(original) == (fps != 30))
        #expect(original.shouldInvalidateSession(settings) == (fps != 30))
        #expect(!settings.shouldInvalidateSession(settings))
        for property in settings.properties()
            where property.key.value != kVTCompressionPropertyKey_ExpectedFrameRate
        {
            let originalProperty = try #require(original.properties()
                .first { $0.key.value == property.key.value })
            #expect((property.value as? NSObject)?.isEqual(originalProperty.value) == true)
        }
    }
}
