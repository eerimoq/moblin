import Foundation
@testable import Moblin
import Testing

struct DjiDeviceSuite {
    @Test
    func startStreamingOmsoPocket4() throws {
        let payload = DjiStartStreamingMessagePayload2(
            rtmpUrl: "rtmp://192.168.1.59/live/1",
            resolution: .r1080p,
            fps: 30,
            bitrateKbps: 5000,
            codec: "HEVC",
            enhancedRtmp: true,
            middle: DjiStartStreamingMessagePayload2.osmoPocket4Middle
        )
        let encoded = payload.encode()
        #expect(encoded.count == 161)
        #expect(encoded[0] == 1)
        #expect(Int(encoded[1]) | (Int(encoded[2]) << 8) == 158)
        #expect(encoded[3 ..< 14].hexString() == "0a88130201030000009300")
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
        let payload = DjiStartStreamingMessagePayload2(
            rtmpUrl: "rtmp://192.168.1.59/live/123456789",
            resolution: .r720p,
            fps: 30,
            bitrateKbps: 7000,
            codec: "AVC",
            enhancedRtmp: false,
            middle: DjiStartStreamingMessagePayload2.osmoAction6Middle
        )
        let encoded = payload.encode()
        #expect(encoded.count == 169)
        #expect(encoded[0] == 1)
        #expect(Int(encoded[1]) | (Int(encoded[2]) << 8) == 166)
        #expect(encoded[3 ..< 14].hexString() == "04581bfe00030000009b00")
        let object = try JSONSerialization.jsonObject(with: encoded[14 ..< 169])
        #expect(object as? NSDictionary == [
            "EnhancedRTMP": 0,
            "codec": "AVC",
            "orientation": "landscape",
            "rtmpAddress": "rtmp://192.168.1.59/live/123456789",
            "supportStopLive": 0,
            "watermark": 0,
        ])
    }

    @Test
    func startStreamingOsmoAction4() {
        let payload = DjiStartStreamingMessagePayload(
            rtmpUrl: "rtmp://110.144.9.240:1935/publish/live",
            resolution: .r1080p,
            fps: 30,
            bitrateKbps: 6000
        )
        #expect(payload.encode().hexString() == """
        0031000a7017020003000000260072746d703a2f2f3131302e3134342e392e3234303a313933352f7075626c6973682f6c697665
        """)
    }

    @Test
    func modelOsmoAction6() {
        let data = Data([
            0xAA, 0x08, 0x18, 0x00, 0xFA, 0x0C, 0x9A, 0xE6,
            0xA0, 0x97, 0x56, 0x00,
        ])
        #expect(djiModelFromManufacturerData(data: data) == .osmoAction6)
    }

    @Test
    func modelOsmoPocket4Pro() {
        var data = Data([
            0xAA, 0x08, 0x00, 0x00, 0x00, 0xCF, 0x00, 0x04,
            0x76, 0xEA, 0x8B, 0x20, 0xDA, 0x00, 0x00, 0x10,
        ])
        #expect(djiModelFromManufacturerData(data: data) == .osmoPocket4Pro)
        data = Data([
            0xAA, 0x08, 0x00, 0x00, 0x00, 0xC1, 0x00, 0x04,
            0xFD, 0x9C, 0xD3, 0x20, 0xDA, 0x00, 0x00, 0x40,
        ])
        #expect(djiModelFromManufacturerData(data: data) == .osmoPocket4Pro)
    }
}
