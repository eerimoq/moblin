import Foundation
@testable import Moblin
import Testing

struct MoblinSettingsUrlSuite {
    @Test
    func previewStream() throws {
        let settings = try MoblinSettingsUrl.fromString(query: """
        {"streams":[{"name":"Studio","url":"srt://example.com:5000?streamid=foo",\
        "previewStream":{"url":"whip://example.com:5000/whip/foo","resolution":"854x480","bitrate":1000000}}]}
        """)
        let previewStream = try #require(settings.streams?.first?.previewStream)
        #expect(previewStream.url == "whip://example.com:5000/whip/foo")
        #expect(previewStream.resolution == .r854x480)
        #expect(previewStream.bitrate == 1_000_000)
    }

    @Test
    func previewStreamUrlOnly() throws {
        let settings = try MoblinSettingsUrl.fromString(query: """
        {"streams":[{"name":"Studio","url":"srt://example.com:5000",\
        "previewStream":{"url":"whips://example.com/whip/foo"}}]}
        """)
        let previewStream = try #require(settings.streams?.first?.previewStream)
        #expect(previewStream.resolution == nil)
        #expect(previewStream.bitrate == nil)
    }

    @Test
    func previewStreamMustBeWhip() {
        #expect(throws: (any Error).self) {
            try MoblinSettingsUrl.fromString(query: """
            {"streams":[{"name":"Studio","url":"srt://example.com:5000",\
            "previewStream":{"url":"rtmp://example.com/live/foo"}}]}
            """)
        }
    }

    @Test
    func noPreviewStream() throws {
        let settings = try MoblinSettingsUrl.fromString(query: """
        {"streams":[{"name":"Studio","url":"srt://example.com:5000"}]}
        """)
        #expect(settings.streams?.first?.previewStream == nil)
    }
}
