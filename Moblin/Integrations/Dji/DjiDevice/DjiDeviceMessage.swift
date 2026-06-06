import Foundation

struct DjiPairMessagePayload {
    static let payload = Data([
        0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62,
        0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37,
        0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31,
        0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61,
        0x33,
    ])
    var pairPinCode: String

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(DjiPairMessagePayload.payload)
        writer.writeBytes(djiPackString(value: pairPinCode))
        return writer.data
    }
}

struct DjiPreparingToLivestreamMessagePayload {
    static let payload = Data([0x1A])

    func encode() -> Data {
        DjiPreparingToLivestreamMessagePayload.payload
    }
}

struct DjiSetupWifiMessagePayload {
    var wifiSsid: String
    var wifiPassword: String

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(djiPackString(value: wifiSsid))
        writer.writeBytes(djiPackString(value: wifiPassword))
        return writer.data
    }
}

struct DjiStartStreamingMessagePayload {
    static let payload1 = Data([0x00])
    static let payload2 = Data([0x00])
    static let payload3 = Data([0x02, 0x00])
    static let payload4 = Data([0x00, 0x00, 0x00])
    var rtmpUrl: String
    var resolution: SettingsDjiDeviceResolution
    var bitrateKbps: UInt16
    var fps: Int
    var oa5: Bool

    init(rtmpUrl: String, resolution: SettingsDjiDeviceResolution, fps: Int, bitrateKbps: UInt16, oa5: Bool) {
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.fps = fps
        self.bitrateKbps = bitrateKbps
        self.oa5 = oa5
    }

    func encode() -> Data {
        let oa5Byte: UInt8 = if oa5 {
            0x2A
        } else {
            0x2E
        }
        let writer = ByteWriter()
        writer.writeBytes(DjiStartStreamingMessagePayload.payload1)
        writer.writeUInt8(oa5Byte)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload2)
        writer.writeUInt8(toDjiResolution(resolution: resolution))
        writer.writeUInt16Le(bitrateKbps)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload3)
        writer.writeUInt8(toDjiFps(fps: fps))
        writer.writeBytes(DjiStartStreamingMessagePayload.payload4)
        writer.writeBytes(djiPackUrl(url: rtmpUrl))
        return writer.data
    }
}

struct DjiConfirmStartStreamingMessagePayload {
    static let payload = Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x01])

    func encode() -> Data {
        DjiConfirmStartStreamingMessagePayload.payload
    }
}

private struct StartStreamingPayload: Codable {
    let codec: String
    let EnhancedRTMP: Bool
    let supportStopLive: Bool
    let watermark: Int
    let rtmpAddress: String
    let orientation: String
}

struct DjiStartStreamingMessagePayload2 {
    static let osmoAction6Header = Data([0x01, 0x9C, 0x00])
    static let osmoAction6Middle = Data([0xFE, 0x00])
    static let osmoPocket4Header = Data([0x01, 0xB5, 0x00])
    static let osmoPocket4Middle = Data([0x02, 0x01])
    private static let padding = Data([0x00, 0x00, 0x00])
    var rtmpUrl: String
    var resolution: SettingsDjiDeviceResolution
    var bitrateKbps: UInt16
    var fps: Int
    var codec: String
    var enhancedRtmp: Bool
    let header: Data
    let middle: Data

    init(
        rtmpUrl: String,
        resolution: SettingsDjiDeviceResolution,
        fps: Int,
        bitrateKbps: UInt16,
        codec: String,
        enhancedRtmp: Bool,
        header: Data,
        middle: Data
    ) {
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.fps = fps
        self.bitrateKbps = bitrateKbps
        self.codec = codec
        self.enhancedRtmp = enhancedRtmp
        self.header = header
        self.middle = middle
    }

    func encode() -> Data {
        let payload = StartStreamingPayload(codec: codec,
                                            EnhancedRTMP: enhancedRtmp,
                                            supportStopLive: false,
                                            watermark: 0,
                                            rtmpAddress: rtmpUrl,
                                            orientation: "landscape")
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let writer = ByteWriter()
        writer.writeBytes(header)
        writer.writeUInt8(toDjiResolution(resolution: resolution))
        writer.writeUInt16Le(bitrateKbps)
        writer.writeBytes(middle)
        writer.writeUInt8(toDjiFps(fps: fps))
        writer.writeBytes(Self.padding)
        writer.writeUInt16Le(UInt16(truncatingIfNeeded: data.count))
        writer.writeBytes(data)
        return writer.data
    }
}

struct DjiStopStreamingMessagePayload {
    static let payload = Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x02])

    func encode() -> Data {
        DjiStopStreamingMessagePayload.payload
    }
}

struct DjiConfigureMessagePayload {
    static let payload1 = Data([0x01, 0x01])
    static let payload2 = Data([0x00, 0x01])

    var imageStabilization: SettingsDjiDeviceImageStabilization
    var oa5: Bool

    func encode() -> Data {
        let imageStabilizationByte: UInt8 = switch imageStabilization {
        case .off:
            0
        case .rockSteady:
            1
        case .rockSteadyPlus:
            3
        case .horizonBalancing:
            4
        case .horizonSteady:
            2
        }
        let byte1: UInt8 = if oa5 {
            0x1A
        } else {
            0x08
        }
        let writer = ByteWriter()
        writer.writeBytes(DjiConfigureMessagePayload.payload1)
        writer.writeUInt8(byte1)
        writer.writeBytes(DjiConfigureMessagePayload.payload2)
        writer.writeUInt8(imageStabilizationByte)
        return writer.data
    }
}

struct DjiStatusMessagePayload {
    let batteryPercentage: UInt8

    init?(payload: Data) {
        guard payload.count >= 21 else {
            return nil
        }
        batteryPercentage = payload[20]
    }
}

private func toDjiFps(fps: Int) -> UInt8 {
    switch fps {
    case 25:
        2
    case 30:
        3
    default:
        0
    }
}

private func toDjiResolution(resolution: SettingsDjiDeviceResolution) -> UInt8 {
    switch resolution {
    case .r480p:
        0x47
    case .r720p:
        0x04
    case .r1080p:
        0x0A
    }
}
