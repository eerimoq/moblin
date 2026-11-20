import Foundation
@testable import Moblin
import Testing

struct RtmpHandshakeSuite {
    @Test
    func c0c1() {
        let packet = RtmpHandshake.createC0C1Packet()
        #expect(packet.count == RtmpHandshake.sigSize + 1)
        #expect(packet.prefix(9) == Data([0x03, 0, 0, 0, 0, 0, 0, 0, 0]))
    }

    @Test
    func c2EchoesServerTimestampAndRandomData() {
        let s0s1 = Data([0x03]) + Data((0 ..< RtmpHandshake.sigSize).map { UInt8($0 % 256) })
        let packet = RtmpHandshake.createC2Packet(s0s1)
        #expect(packet.count == RtmpHandshake.sigSize)
        #expect(packet.prefix(4) == s0s1[1 ..< 5])
        #expect(packet.suffix(from: 8) == s0s1.suffix(from: 9))
    }

    @Test
    func c2ContainsCurrentTime() {
        let s0s1 = Data(count: RtmpHandshake.sigSize + 1)
        let before = UInt32(Date().timeIntervalSince1970)
        let packet = RtmpHandshake.createC2Packet(s0s1)
        let after = UInt32(Date().timeIntervalSince1970)
        let time = UInt32(data: packet[4 ..< 8]).bigEndian
        #expect(time >= before)
        #expect(time <= after)
    }
}

struct RtmpSanJoseAuthSuite {
    private let url = URL(string: "rtmp://user:pass@foo.com/app")!

    @Test
    func withOpaque() throws {
        let command = makeSanJoseAuthCommand(
            url,
            description: "[ AccessManager.Reject ] : [ authmod=adobe ] : ?reason=needauth&user=user&salt=abc"
                + "&challenge=def&opaque=ghi"
        )
        let match = try #require(
            command
                .wholeMatch(
                    of: /rtmp:\/\/user:pass@foo\.com\/app&opaque=ghi&challenge=([0-9a-f]{8})&response=(.+)/
                )
        )
        let challenge = String(match.output.1)
        let expected = calculateMd5Base64(calculateMd5Base64("userabcpass") + "ghi" + challenge)
        #expect(match.output.2 == expected)
    }

    @Test
    func withChallengeWithoutOpaque() throws {
        let command = makeSanJoseAuthCommand(
            url,
            description: "?reason=needauth&user=user&salt=abc&challenge=def"
        )
        let match = try #require(
            command.wholeMatch(of: /rtmp:\/\/user:pass@foo\.com\/app&challenge=([0-9a-f]{8})&response=(.+)/)
        )
        let challenge = String(match.output.1)
        let expected = calculateMd5Base64(calculateMd5Base64("userabcpass") + "def" + challenge)
        #expect(match.output.2 == expected)
    }

    @Test
    func withoutQuery() {
        #expect(makeSanJoseAuthCommand(url, description: "reason=needauth") == url.absoluteString)
    }

    @Test
    func withoutSalt() {
        #expect(makeSanJoseAuthCommand(url, description: "?reason=needauth&challenge=def") == url
            .absoluteString)
    }

    @Test
    func withoutPassword() throws {
        let url = try #require(URL(string: "rtmp://user@foo.com/app"))
        #expect(makeSanJoseAuthCommand(url, description: "?reason=needauth&salt=abc") == url.absoluteString)
    }
}
