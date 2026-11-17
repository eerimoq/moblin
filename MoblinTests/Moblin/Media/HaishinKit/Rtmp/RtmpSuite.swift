import AVFoundation
@testable import Moblin
import Testing

struct RtmpSuite {
    @Test
    func twitchUrl() {
        let url = "rtmp://foo.com/app/live_asefwefwefwef"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/app")
        #expect(streamKey == "live_asefwefwefwef")
    }

    @Test
    func kickUrl() {
        let url = "rtmp://foo.com/foobar"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com")
        #expect(streamKey == "foobar")
    }

    @Test
    func bilibiliUrl() {
        let url = "rtmp://foo.com/live/?foo=bar&a=b"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/live")
        #expect(streamKey == "?foo=bar&a=b")
    }

    private func makeConnectResultChunkData() -> Data {
        RtmpChunk(message: RtmpCommandMessage(
            streamId: 0,
            transactionId: 1,
            commandType: .amf0Command,
            commandName: .result,
            commandObject: nil,
            arguments: [.object(["code": .string("NetConnection.Connect.Success")])]
        )).encode()
    }

    @Test
    func connectResultInOneRead() {
        let rtmpStream = makeRtmpStream()
        var arguments: [AsValue]?
        rtmpStream.callCompletions[1] = { arguments = $0 }
        #expect(rtmpStream.socketDataReceived(data: makeConnectResultChunkData()).isEmpty)
        #expect(arguments?.count == 1)
    }

    @Test
    func connectResultSplitAfterChunkHeader() {
        let rtmpStream = makeRtmpStream()
        var arguments: [AsValue]?
        rtmpStream.callCompletions[1] = { arguments = $0 }
        let data = makeConnectResultChunkData()
        let buffer = rtmpStream.socketDataReceived(data: data.subdata(in: 0 ..< 12))
        #expect(buffer == data.subdata(in: 0 ..< 12))
        #expect(rtmpStream.socketDataReceived(data: buffer + data.advanced(by: 12)).isEmpty)
        #expect(arguments?.count == 1)
    }

    @Test
    func twitcastingUrl() {
        let url = "rtmp://foo.com/live/g:3234234?key=1234"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/live")
        #expect(streamKey == "g:3234234?key=1234")
    }
}

private func makeRtmpStream() -> RtmpStream {
    let modelMock = RtmpModelMock()
    return RtmpStream(name: "test",
                      processor: Processor(delegate: modelMock, colorRange: .full),
                      delegate: modelMock,
                      queue: DispatchQueue(label: "test"))
}
