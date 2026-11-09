import Foundation
@testable import Moblin
import Testing

struct MoblinSettingsUrlSuite {
    struct InvalidCase: CustomTestStringConvertible {
        let testDescription: String
        let query: String
        let message: String

        init(_ description: String, _ query: String, _ message: String) {
            testDescription = description
            self.query = query
            self.message = message
        }
    }

    @Test(arguments: [
        InvalidCase("stream url without port",
                    #"{"streams":[{"name":"a","url":"srt://host"}]}"#,
                    String(localized: "SRT(LA) port number missing")),
        InvalidCase("negative srt latency",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","srt":{"latency":-1}}]}"#,
                    "Negative SRT latency"),
        InvalidCase("too big srt latency",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","srt":{"latency":65536}}]}"#,
                    "Too big SRT latency"),
        InvalidCase("obs websocket url with http scheme",
                    #"""
                    {"streams":[{"name":"a","url":"srt://host:5000",
                    "obs":{"webSocketUrl":"http://host:4455","webSocketPassword":""}}]}
                    """#,
                    String(localized: "Unsupported scheme \("http")")),
        InvalidCase("moblin cloud url with ftp scheme",
                    #"{"moblinCloud":{"enabled":true,"key":"k","url":"ftp://host"}}"#,
                    String(localized: "Unsupported scheme \("ftp")")),
    ])
    func invalid(invalidCase: InvalidCase) {
        let error = #expect(throws: (any Error).self) {
            try MoblinSettingsUrl.fromString(query: invalidCase.query)
        }
        #expect(error?.localizedDescription == invalidCase.message)
    }
}
