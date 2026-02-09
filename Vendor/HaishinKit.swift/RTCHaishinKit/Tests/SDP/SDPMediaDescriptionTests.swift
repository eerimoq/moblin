import AVFoundation
import Foundation
import Testing

@testable import RTCHaishinKit

@Suite struct SDPMediaDescriptionTests {
    @Test func opus() throws {
        let sdp = """
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        c=IN IP4 0.0.0.0
        a=rtpmap:111 opus/48000/2
        a=fmtp:111 minptime=10;useinbandfec=1
        a=rtcp-mux
        a=rtcp-rsize
        a=sendrecv
        a=mid:0
        """

        let mediaDescription = try SDPMediaDescription(sdp: sdp)
        #expect(mediaDescription.kind == "audio")
        #expect(mediaDescription.payload == 111)
        for attributes in mediaDescription.attributes {
            switch attributes {
            case .rtpmap(let payload, let codec, let clock, let channels):
                #expect(payload == 111)
                #expect(codec == "opus")
                #expect(clock == 48000)
                #expect(channels == 2)
            case .mid(let mid):
                #expect(mid == "0")
            default:
                break
            }
        }
        let rtpmap = mediaDescription.attributes.compactMap { attr -> (UInt8, String, Int, Int?)? in
            if case let .rtpmap(payload, codec, clock, channel) = attr { return (payload, codec, clock, channel) }
            return nil
        }
        #expect(rtpmap[0].0 == 111)
        #expect(rtpmap[0].1 == "opus")
        #expect(rtpmap[0].2 == 48000)
        #expect(rtpmap[0].3 == 2)
    }

    @Test func vp8() throws {
        let sdp = """
        m=video 9 UDP/TLS/RTP/SAVPF 96
        c=IN IP4 0.0.0.0
        a=rtpmap:96 VP8/90000
        a=rtcp-fb:96 ccm fir
        a=rtcp-fb:96 nack
        a=rtcp-fb:96 nack pli
        a=rtcp-fb:96 goog-remb
        a=rtcp-fb:96 transport-cc
        a=rtcp-mux
        a=rtcp-rsize
        a=sendrecv
        a=mid:1
        """
        let mediaDescription = try SDPMediaDescription(sdp: sdp)
        #expect(mediaDescription.kind == "video")
        #expect(mediaDescription.payload == 96)
    }
}
