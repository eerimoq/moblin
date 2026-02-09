import Foundation
import HaishinKit
@testable import SRTHaishinKit
import Testing

@Suite actor SRTStreamTests {
    @Test func unsupportedAudioCodec() async {
        await #expect(throws: SRTStream.Error.unsupportedCodec.self) {
            let stream = SRTStream(connection: .init())
            var audio = AudioCodecSettings()
            audio.format = .opus
            try await stream.setAudioSettings(audio)
        }
    }
}
