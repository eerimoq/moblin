import Foundation
@testable import Moblin
import Testing

struct RtspClientSuite {
    @Test
    func tcpTransportAcceptsValidInterleavedChannels() throws {
        let transport = RtspTransportRtpRtspTcp()
        try transport.handleSetupTransportResponse("RTP/AVP/TCP;unicast;interleaved=0-1")
    }

    @Test
    func tcpTransportRejectsInvalidInterleavedChannels() {
        let transport = RtspTransportRtpRtspTcp()
        #expect(throws: "Invalid interleaving channels in RTP/AVP/TCP;unicast;interleaved=256-257.") {
            try transport.handleSetupTransportResponse("RTP/AVP/TCP;unicast;interleaved=256-257")
        }
    }

    @Test
    func udpTransportAcceptsValidServerPorts() throws {
        let transport = RtspTransportRtpUdp()
        try transport.handleSetupTransportResponse("RTP/AVP;unicast;server_port=5004-5005")
    }

    @Test
    func udpTransportRejectsInvalidRtpServerPort() {
        let transport = RtspTransportRtpUdp()
        #expect(throws: "Invalid RTP or RTCP server port in: RTP/AVP;unicast;server_port=999999-5005") {
            try transport.handleSetupTransportResponse("RTP/AVP;unicast;server_port=999999-5005")
        }
    }
}
