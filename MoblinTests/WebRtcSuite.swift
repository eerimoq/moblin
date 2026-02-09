@testable import Moblin
import Testing

struct WebRtcSuite {
    // MARK: - RTP Packet Tests

    @Test
    func rtpHeaderEncode() {
        let header = RtpHeader(
            payloadType: 96,
            sequenceNumber: 1000,
            timestamp: 160_000,
            ssrc: 0x1234_5678
        )
        let data = header.encode()
        #expect(data.count == 12)
        #expect(data[0] == 0x80) // version 2, no padding/extension/csrc
        #expect(data[1] == 96) // payload type, no marker
        #expect(data[2] == 0x03) // seq high
        #expect(data[3] == 0xE8) // seq low (1000)
    }

    @Test
    func rtpHeaderEncodeWithMarker() {
        let header = RtpHeader(
            marker: true,
            payloadType: 111,
            sequenceNumber: 0,
            timestamp: 0,
            ssrc: 0
        )
        let data = header.encode()
        #expect(data[1] == 0x80 | 111)
    }

    @Test
    func rtpHeaderDecodeRoundtrip() {
        let original = RtpHeader(
            payloadType: 96,
            sequenceNumber: 42,
            timestamp: 90_000,
            ssrc: 0xDEAD_BEEF
        )
        let data = original.encode()
        let decoded = RtpHeader.decode(from: data)
        #expect(decoded != nil)
        #expect(decoded?.version == 2)
        #expect(decoded?.payloadType == 96)
        #expect(decoded?.sequenceNumber == 42)
        #expect(decoded?.timestamp == 90_000)
        #expect(decoded?.ssrc == 0xDEAD_BEEF)
    }

    @Test
    func rtpHeaderDecodeTooShort() {
        let data = Data([0x80, 0x60, 0x00])
        #expect(RtpHeader.decode(from: data) == nil)
    }

    @Test
    func rtpSequencerWraps() {
        let sequencer = RtpSequencer(payloadType: 96, clockRate: 90_000, ssrc: 1)
        var lastSeq: UInt16 = 0
        for _ in 0 ..< 70000 {
            lastSeq = sequencer.nextSequenceNumber()
        }
        // Should have wrapped around
        #expect(lastSeq < 70000)
    }

    // MARK: - STUN Message Tests

    @Test
    func stunMessageEncodeDecodeRoundtrip() {
        let transactionId = StunMessage.generateTransactionId()
        let original = StunMessage(type: .bindingRequest, transactionId: transactionId)
        let data = original.encode()
        let decoded = StunMessage.decode(from: data)
        #expect(decoded != nil)
        #expect(decoded?.type == .bindingRequest)
        #expect(decoded?.transactionId == transactionId)
    }

    @Test
    func stunMessageDecodeTooShort() {
        let data = Data(count: 10)
        #expect(StunMessage.decode(from: data) == nil)
    }

    @Test
    func stunMessageWithAttributes() {
        let username = "user:remote"
        let msg = stunCreateBindingRequest(
            username: username,
            iceControlling: 12345,
            priority: 2_130_706_431
        )
        let data = msg.encode()
        let decoded = StunMessage.decode(from: data)
        #expect(decoded != nil)
        #expect(decoded?.type == .bindingRequest)
        #expect(decoded?.attributes.count == 4)
    }

    @Test
    func stunIsBindingResponseCheck() {
        var data = Data(count: 20)
        data[0] = 0x01
        data[1] = 0x01
        data[4] = 0x21
        data[5] = 0x12
        data[6] = 0xA4
        data[7] = 0x42
        #expect(stunIsBindingResponse(data) == true)

        data[0] = 0x00
        data[1] = 0x01
        #expect(stunIsBindingResponse(data) == false)
    }

    // MARK: - SDP Message Tests

    @Test
    func sdpCreateOfferContainsAudioAndVideo() {
        let sdp = sdpCreateOffer(
            videoSsrc: 1000,
            audioSsrc: 2000,
            videoPayloadType: 96,
            audioPayloadType: 111,
            iceUfrag: "testufrag",
            icePwd: "testpwd",
            fingerprint: "sha-256 AA:BB:CC"
        )
        #expect(sdp.media.count == 2)
        #expect(sdp.media[0].type == .audio)
        #expect(sdp.media[1].type == .video)
        #expect(sdp.iceUfrag == "testufrag")
        #expect(sdp.icePwd == "testpwd")
        #expect(sdp.fingerprint == "sha-256 AA:BB:CC")
    }

    @Test
    func sdpEncodeDecodeRoundtrip() {
        let sdp = sdpCreateOffer(
            videoSsrc: 1000,
            audioSsrc: 2000,
            videoPayloadType: 96,
            audioPayloadType: 111,
            iceUfrag: "ufrag123",
            icePwd: "pwd456",
            fingerprint: "sha-256 AA:BB:CC:DD"
        )
        let encoded = sdp.encode()
        let decoded = SdpMessage.decode(from: encoded)
        #expect(decoded.media.count == 2)
        #expect(decoded.iceUfrag == "ufrag123")
        #expect(decoded.icePwd == "pwd456")
        #expect(decoded.fingerprint == "sha-256 AA:BB:CC:DD")
        #expect(decoded.media[0].type == .audio)
        #expect(decoded.media[1].type == .video)
        #expect(decoded.media[0].mid == "0")
        #expect(decoded.media[1].mid == "1")
    }

    @Test
    func sdpDecodeAnswer() {
        let answerSdp = """
        v=0\r
        o=- 0 0 IN IP4 127.0.0.1\r
        s=-\r
        t=0 0\r
        a=group:BUNDLE 0 1\r
        a=ice-ufrag:remote\r
        a=ice-pwd:remotepwd\r
        a=fingerprint:sha-256 AB:CD:EF\r
        a=setup:active\r
        m=audio 9 UDP/TLS/RTP/SAVPF 111\r
        a=mid:0\r
        a=rtpmap:111 opus/48000/2\r
        a=candidate:1 1 UDP 2130706431 192.168.1.1 5000 typ host\r
        m=video 9 UDP/TLS/RTP/SAVPF 96\r
        a=mid:1\r
        a=rtpmap:96 H264/90000\r
        """
        let decoded = SdpMessage.decode(from: answerSdp)
        #expect(decoded.iceUfrag == "remote")
        #expect(decoded.icePwd == "remotepwd")
        #expect(decoded.media.count == 2)
        #expect(decoded.media[0].candidates.count == 1)
        #expect(decoded.media[0].candidates[0].address == "192.168.1.1")
        #expect(decoded.media[0].candidates[0].port == 5000)
    }

    @Test
    func sdpOfferContainsSendonly() {
        let sdp = sdpCreateOffer(
            videoSsrc: 100,
            audioSsrc: 200,
            videoPayloadType: 96,
            audioPayloadType: 111,
            iceUfrag: "u",
            icePwd: "p",
            fingerprint: "sha-256 AA:BB"
        )
        let encoded = sdp.encode()
        #expect(encoded.contains("a=sendonly"))
        #expect(encoded.contains("a=rtcp-mux"))
    }

    @Test
    func sdpOfferContainsFingerprint() {
        let sdp = sdpCreateOffer(
            videoSsrc: 100,
            audioSsrc: 200,
            videoPayloadType: 96,
            audioPayloadType: 111,
            iceUfrag: "u",
            icePwd: "p",
            fingerprint: "sha-256 AA:BB:CC:DD:EE:FF"
        )
        let encoded = sdp.encode()
        #expect(encoded.contains("a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF"))
    }

    // MARK: - ICE Agent Tests

    @Test
    func iceAgentGeneratesCredentials() {
        let agent = IceAgent()
        #expect(!agent.ufrag.isEmpty)
        #expect(!agent.pwd.isEmpty)
        #expect(agent.ufrag.count == 4)
        #expect(agent.pwd.count == 22)
    }

    @Test
    func iceGenerateStringUniqueness() {
        let str1 = IceAgent.generateIceString(length: 16)
        let str2 = IceAgent.generateIceString(length: 16)
        #expect(str1 != str2)
    }

    // MARK: - WHIP URL Tests

    @Test
    func whipToHttpsUrlConversion() {
        #expect(whipToHttpsUrl("whip://server.com/whip/endpoint") == "https://server.com/whip/endpoint")
    }

    @Test
    func whipToHttpsUrlNoConversion() {
        #expect(whipToHttpsUrl("https://server.com/whip/endpoint") == "https://server.com/whip/endpoint")
    }

    // MARK: - Settings Integration Tests

    @Test
    func settingsStreamProtocolWebRtc() {
        let stream = SettingsStream(name: "test")
        stream.url = "whip://server.com/live"
        #expect(stream.getProtocol() == .webRtc)
        #expect(stream.getDetailedProtocol() == .webRtc)
    }

    @Test
    func settingsStreamProtocolStringWebRtc() {
        let stream = SettingsStream(name: "test")
        stream.url = "whip://server.com/live"
        #expect(stream.protocolString() == "WebRTC")
    }
}
