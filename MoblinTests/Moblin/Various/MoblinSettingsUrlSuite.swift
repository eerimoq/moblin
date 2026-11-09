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
        InvalidCase("unsupported video fps",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"fps":24}}]}"#,
                    "Unsupported video FPS"),
        InvalidCase("too small video bitrate",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"bitrate":49999}}]}"#,
                    "Video bitrate out of range"),
        InvalidCase("too big video bitrate",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"bitrate":50000001}}]}"#,
                    "Video bitrate out of range"),
        InvalidCase("negative max key frame interval",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"maxKeyFrameInterval":-1}}]}"#,
                    "Max key frame interval out of range"),
        InvalidCase("too big max key frame interval",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"maxKeyFrameInterval":11}}]}"#,
                    "Max key frame interval out of range"),
        InvalidCase("audio bitrate not a multiple of 32000",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","audio":{"bitrate":100000}}]}"#,
                    "Unsupported audio bitrate"),
        InvalidCase("too big audio bitrate",
                    #"{"streams":[{"name":"a","url":"srt://host:5000","audio":{"bitrate":352000}}]}"#,
                    "Unsupported audio bitrate"),
    ])
    func invalid(invalidCase: InvalidCase) {
        let error = #expect(throws: (any Error).self) {
            try MoblinSettingsUrl.fromString(query: invalidCase.query)
        }
        #expect(error?.localizedDescription == invalidCase.message)
    }

    struct ValidCase: CustomTestStringConvertible {
        let testDescription: String
        let query: String

        init(_ description: String, _ query: String) {
            testDescription = description
            self.query = query
        }
    }

    @Test(arguments: [
        ValidCase("video fps 30",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"fps":30}}]}"#),
        ValidCase("smallest video bitrate",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"bitrate":50000}}]}"#),
        ValidCase("biggest video bitrate",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"bitrate":50000000}}]}"#),
        ValidCase("smallest max key frame interval",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"maxKeyFrameInterval":0}}]}"#),
        ValidCase("biggest max key frame interval",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","video":{"maxKeyFrameInterval":10}}]}"#),
        ValidCase("smallest audio bitrate",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","audio":{"bitrate":32000}}]}"#),
        ValidCase("biggest audio bitrate",
                  #"{"streams":[{"name":"a","url":"srt://host:5000","audio":{"bitrate":320000}}]}"#),
    ])
    func valid(validCase: ValidCase) {
        #expect(throws: Never.self) {
            try MoblinSettingsUrl.fromString(query: validCase.query)
        }
    }

    struct CleanUrlCase: CustomTestStringConvertible {
        let testDescription: String
        let url: String
        let cleanedUrl: String

        init(_ url: String, _ cleanedUrl: String) {
            testDescription = url
            self.url = url
            self.cleanedUrl = cleanedUrl
        }
    }

    @Test(arguments: [
        CleanUrlCase("srt://host:5000", "srt://host:5000"),
        CleanUrlCase("SRTLA://host:5000", "srtla://host:5000"),
        CleanUrlCase("srt://host :5000", "srt://host:5000"),
        CleanUrlCase(" srt://host:5000\\n", "srt://host:5000"),
    ])
    func streamUrlIsCleaned(cleanUrlCase: CleanUrlCase) throws {
        let query = #"{"streams":[{"name":"a","url":"\#(cleanUrlCase.url)"}]}"#
        #expect(try MoblinSettingsUrl.fromString(query: query).streams?.first?.url == cleanUrlCase.cleanedUrl)
    }

    @Test(arguments: [
        CleanUrlCase("ws://host:4455", "ws://host:4455"),
        CleanUrlCase("WSS://host:4455", "wss://host:4455"),
        CleanUrlCase("ws://host :4455", "ws://host:4455"),
        CleanUrlCase(" ws://host:4455\\n", "ws://host:4455"),
    ])
    func obsWebSocketUrlIsCleaned(cleanUrlCase: CleanUrlCase) throws {
        let query = #"""
        {"streams":[{"name":"a","url":"srt://host:5000",
        "obs":{"webSocketUrl":"\#(cleanUrlCase.url)","webSocketPassword":""}}]}
        """#
        #expect(try MoblinSettingsUrl.fromString(query: query).streams?.first?.obs?
            .webSocketUrl == cleanUrlCase.cleanedUrl)
    }
}
