import Foundation
@testable import Moblin
import Testing

struct DjiDeviceSuite {
    @Test
    func startStreamingOmsoPocket4() throws {
        let payload = DjiStartStreamingMessagePayloadPocket4(
            rtmpUrl: "rtmp://192.168.1.59/live/1",
            resolution: .r1080p,
            fps: 30,
            bitrateKbps: 5000,
            codec: "HEVC",
            enhancedRtmp: true
        )
        let encoded = payload.encode()
        #expect(encoded.count == 161)
        #expect(encoded[0 ..< 14].hexString() == "01b5000a88130201030000009300")
        let object = try JSONSerialization.jsonObject(with: encoded[14 ..< 161])
        #expect(object as? NSDictionary == [
            "EnhancedRTMP": 1,
            "codec": "HEVC",
            "orientation": "landscape",
            "rtmpAddress": "rtmp://192.168.1.59/live/1",
            "supportStopLive": 0,
            "watermark": 0,
        ])
    }

    @Test
    func startStreamingOmsoAction6() throws {
        let payload = DjiStartStreamingMessagePayloadOsmoAction6(
            rtmpUrl: "rtmp://192.168.1.59/live/2",
            resolution: .r720p,
            fps: 30,
            bitrateKbps: 7000,
            codec: "AVC",
            enhancedRtmp: false
        )
        let encoded = payload.encode()
        #expect(encoded.count == 161)
        #expect(encoded[0 ..< 14].hexString() == "019c0004581bfe00030000009300")
        let object = try JSONSerialization.jsonObject(with: encoded[14 ..< 161])
        #expect(object as? NSDictionary == [
            "EnhancedRTMP": 0,
            "codec": "AVC",
            "orientation": "landscape",
            "rtmpAddress": "rtmp://192.168.1.59/live/2",
            "supportStopLive": 0,
            "watermark": 0,
        ])
    }
}
