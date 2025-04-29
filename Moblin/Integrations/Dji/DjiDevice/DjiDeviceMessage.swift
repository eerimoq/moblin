import Foundation

class DjiPairMessagePayload {
    static let payload = Data([
        0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62,
        0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37,
        0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31,
        0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61,
        0x33,
    ])
    var pairPinCode: String

    init(pairPinCode: String) {
        self.pairPinCode = pairPinCode
    }

    func encode() -> Data {
        let writer = ByteArray()
        writer.writeBytes(DjiPairMessagePayload.payload)
        writer.writeBytes(djiPackString(value: pairPinCode))
        return writer.data
    }
}

class DjiPreparingToLivestreamMessagePayload {
    static let payload = Data([0x1A])

    func encode() -> Data {
        return DjiPreparingToLivestreamMessagePayload.payload
    }
}

class DjiSetupWifiMessagePayload {
    var wifiSsid: String
    var wifiPassword: String

    init(wifiSsid: String, wifiPassword: String) {
        self.wifiSsid = wifiSsid
        self.wifiPassword = wifiPassword
    }

    func encode() -> Data {
        let writer = ByteArray()
        writer.writeBytes(djiPackString(value: wifiSsid))
        writer.writeBytes(djiPackString(value: wifiPassword))
        return writer.data
    }
}

class DjiStartStreamingMessagePayload {
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
        var resolutionByte: UInt8
        switch resolution {
        case .r480p:
            resolutionByte = 0x47
        case .r720p:
            resolutionByte = 0x04
        case .r1080p:
            resolutionByte = 0x0A
        }
        var fpsByte: UInt8
        switch fps {
        case 25:
            fpsByte = 2
        case 30:
            fpsByte = 3
        default:
            fpsByte = 0
        }
        var byte1: UInt8
        if oa5 {
            byte1 = 0x2A
        } else {
            byte1 = 0x2E
        }
        let writer = ByteArray()
        writer.writeBytes(DjiStartStreamingMessagePayload.payload1)
        writer.writeUInt8(byte1)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload2)
        writer.writeUInt8(resolutionByte)
        writer.writeUInt16Le(bitrateKbps)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload3)
        writer.writeUInt8(fpsByte)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload4)
        writer.writeBytes(djiPackUrl(url: rtmpUrl))
        return writer.data
    }
}

class DjiConfirmStartStreamingMessagePayload {
    static let payload = Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x01])

    func encode() -> Data {
        return DjiConfirmStartStreamingMessagePayload.payload
    }
}

class DjiStopStreamingMessagePayload {
    static let payload = Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x02])

    func encode() -> Data {
        return DjiStopStreamingMessagePayload.payload
    }
}

class DjiConfigureMessagePayload {
    static let payload1 = Data([0x01, 0x01])
    static let payload2 = Data([0x00, 0x01])

    var imageStabilization: SettingsDjiDeviceImageStabilization
    var oa5: Bool

    init(imageStabilization: SettingsDjiDeviceImageStabilization, oa5: Bool) {
        self.imageStabilization = imageStabilization
        self.oa5 = oa5
    }

    func encode() -> Data {
        var imageStabilizationByte: UInt8
        switch imageStabilization {
        case .off:
            imageStabilizationByte = 0
        case .rockSteady:
            imageStabilizationByte = 1
        case .rockSteadyPlus:
            imageStabilizationByte = 3
        case .horizonBalancing:
            imageStabilizationByte = 4
        case .horizonSteady:
            imageStabilizationByte = 2
        }
        var byte1: UInt8
        if oa5 {
            byte1 = 0x1A
        } else {
            byte1 = 0x08
        }
        let writer = ByteArray()
        writer.writeBytes(DjiConfigureMessagePayload.payload1)
        writer.writeUInt8(byte1)
        writer.writeBytes(DjiConfigureMessagePayload.payload2)
        writer.writeUInt8(imageStabilizationByte)
        return writer.data
    }
}
