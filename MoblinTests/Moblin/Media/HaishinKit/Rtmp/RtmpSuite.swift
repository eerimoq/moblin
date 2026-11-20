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
        #expect(rtmpStream.socketDataReceived(rtmpStream.socket, data: makeConnectResultChunkData()).isEmpty)
        #expect(arguments?.count == 1)
    }

    @Test
    func connectResultSplitAfterChunkHeader() {
        let rtmpStream = makeRtmpStream()
        var arguments: [AsValue]?
        rtmpStream.callCompletions[1] = { arguments = $0 }
        let data = makeConnectResultChunkData()
        let buffer = rtmpStream.socketDataReceived(rtmpStream.socket, data: data.subdata(in: 0 ..< 12))
        #expect(buffer == data.subdata(in: 0 ..< 12))
        #expect(rtmpStream.socketDataReceived(rtmpStream.socket, data: buffer + data.advanced(by: 12))
            .isEmpty)
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
    makeRtmpStream(modelMock: RtmpModelMock())
}

private func makeRtmpStream(modelMock: RtmpModelMock) -> RtmpStream {
    RtmpStream(name: "test",
               processor: Processor(delegate: modelMock, colorRange: .full),
               delegate: modelMock,
               queue: DispatchQueue(label: "test"))
}

private func makeCommandChunkData(transactionId: Int,
                                  commandName: RtmpCommandName,
                                  arguments: [AsValue]) -> Data
{
    RtmpChunk(message: RtmpCommandMessage(
        streamId: 0,
        transactionId: transactionId,
        commandType: .amf0Command,
        commandName: commandName,
        commandObject: nil,
        arguments: arguments
    )).encode()
}

private func makeStatusChunkData(code: String) -> Data {
    makeCommandChunkData(transactionId: 0,
                         commandName: .onStatus,
                         arguments: [.object(["code": .string(code)])])
}

struct RtmpStreamEventsSuite {
    @Test
    func disconnectsAreReportedInOrderWhileReading() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        let data = makeStatusChunkData(code: "NetConnection.Connect.Failed")
            + makeStatusChunkData(code: "NetConnection.Connect.Closed")
        #expect(rtmpStream.socketDataReceived(rtmpStream.socket, data: data).isEmpty)
        #expect(modelMock.getDisconnectedReasons() == [.connectFailed, .serverClosed])
    }

    @Test
    func disconnectFromCurrentSocketIsReported() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        rtmpStream.socketDisconnected(rtmpStream.socket, code: .connectFailed)
        #expect(modelMock.getDisconnectedReasons() == [.connectFailed])
    }

    @Test
    func disconnectFromOldSocketIsIgnored() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        rtmpStream.socketDisconnected(RtmpSocket(name: "old", queue: DispatchQueue(label: "test")),
                                      code: .connectFailed)
        #expect(modelMock.getDisconnectedReasons().isEmpty)
    }

    @Test
    func dataFromOldSocketIsIgnored() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        _ = rtmpStream.socketDataReceived(RtmpSocket(name: "old", queue: DispatchQueue(label: "test")),
                                          data: makeStatusChunkData(code: "NetConnection.Connect.Failed"))
        #expect(modelMock.getDisconnectedReasons().isEmpty)
    }

    @Test
    func messagesAfterCloseCommandAreIgnored() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        let data = makeCommandChunkData(transactionId: 0, commandName: .close, arguments: [])
            + makeStatusChunkData(code: "NetConnection.Connect.Failed")
        _ = rtmpStream.socketDataReceived(rtmpStream.socket, data: data)
        #expect(modelMock.getDisconnectedReasons().isEmpty)
    }

    @Test
    func messagesAfterConnectClosedStatusAreIgnored() {
        let modelMock = RtmpModelMock()
        let rtmpStream = makeRtmpStream(modelMock: modelMock)
        let data = makeStatusChunkData(code: "NetConnection.Connect.Closed")
            + makeStatusChunkData(code: "NetConnection.Connect.Failed")
        _ = rtmpStream.socketDataReceived(rtmpStream.socket, data: data)
        #expect(modelMock.getDisconnectedReasons() == [.serverClosed])
    }
}
