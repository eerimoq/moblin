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
        let connection = RtmpConnection(name: "test", queue: DispatchQueue(label: "test"))
        var arguments: [AsValue]?
        connection.callCompletions[1] = { arguments = $0 }
        #expect(connection.socketDataReceived(data: makeConnectResultChunkData()).isEmpty)
        #expect(arguments?.count == 1)
    }

    @Test
    func connectResultSplitAfterChunkHeader() {
        let connection = RtmpConnection(name: "test", queue: DispatchQueue(label: "test"))
        var arguments: [AsValue]?
        connection.callCompletions[1] = { arguments = $0 }
        let data = makeConnectResultChunkData()
        let buffer = connection.socketDataReceived(data: data.subdata(in: 0 ..< 12))
        #expect(buffer == data.subdata(in: 0 ..< 12))
        #expect(connection.socketDataReceived(data: buffer + data.advanced(by: 12)).isEmpty)
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
