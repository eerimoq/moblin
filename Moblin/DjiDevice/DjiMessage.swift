import CrcSwift
import Foundation

private func djiCrc8(data: Data) -> UInt8 {
    return CrcSwift.computeCrc8(
        data,
        initialCrc: 0xEE,
        polynom: 0x31,
        xor: 0x00,
        refIn: true,
        refOut: true
    )
}

private func djiCrc16(data: Data) -> UInt16 {
    return CrcSwift.computeCrc16(
        data,
        initialCrc: 0x496C,
        polynom: 0x1021,
        xor: 0x0000,
        refIn: true,
        refOut: true
    )
}

func djiPackString(value: String) -> Data {
    let data = value.utf8Data
    return Data([UInt8(data.count)]) + data
}

func djiPackUrl(url: String) -> Data {
    let data = url.utf8Data
    return Data([UInt8(data.count), 0]) + data
}

class DjiMessage {
    var target: UInt16
    var id: UInt16
    var type: UInt32
    var payload: Data

    init(target: UInt16, id: UInt16, type: UInt32, payload: Data) {
        self.target = target
        self.id = id
        self.type = type
        self.payload = payload
    }

    init(data: Data) throws {
        let reader = ByteArray(data: data)
        guard try reader.readUInt8() == 0x55 else {
            throw "Bad first byte"
        }
        let length = try reader.readUInt8()
        guard data.count == length else {
            throw "Bad length"
        }
        guard try reader.readUInt8() == 0x04 else {
            throw "Bad version"
        }
        let hedaerCrc = try reader.readUInt8()
        let calculatedHeaderCrc = djiCrc8(data: data.subdata(in: 0 ..< 3))
        guard hedaerCrc == calculatedHeaderCrc else {
            throw "Calculated CRC \(calculatedHeaderCrc) does not match received CRC \(hedaerCrc)"
        }
        target = try reader.readUInt16Le()
        id = try reader.readUInt16Le()
        type = try reader.readUInt24Le()
        payload = try reader.readBytes(reader.bytesAvailable - 2)
        let crc = try reader.readUInt16Le()
        let data = data.subdata(in: 0 ..< data.count - 2)
        let calculatedCrc = djiCrc16(data: data)
        guard crc == calculatedCrc else {
            throw "Calculated CRC \(calculatedCrc) does not match received CRC \(crc)"
        }
    }

    func encode() -> Data {
        let writer = ByteArray()
        writer.writeUInt8(0x55)
        writer.writeUInt8(UInt8(13 + payload.count))
        writer.writeUInt8(0x04)
        writer.writeUInt8(djiCrc8(data: writer.data))
        writer.writeUInt16Le(target)
        writer.writeUInt16Le(id)
        writer.writeUInt24Le(type)
        writer.writeBytes(payload)
        let crc = djiCrc16(data: writer.data)
        return writer.writeUInt16Le(crc).data
    }

    // periphery:ignore
    func format() -> String {
        return "target: \(target), id: \(id), type: \(type) \(payload.hexString())"
    }
}

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
    static let payload1 = Data([0x00, 0x2E, 0x00])
    static let payload2 = Data([0x02, 0x00])
    static let payload3 = Data([0x00, 0x00, 0x00])
    var rtmpUrl: String
    var resolution: SettingsDjiDeviceResolution
    var bitrateKbps: UInt16
    var fps: Int

    init(rtmpUrl: String, resolution: SettingsDjiDeviceResolution, fps: Int, bitrateKbps: UInt16) {
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.fps = fps
        self.bitrateKbps = bitrateKbps
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
        let writer = ByteArray()
        writer.writeBytes(DjiStartStreamingMessagePayload.payload1)
        writer.writeUInt8(resolutionByte)
        writer.writeUInt16Le(bitrateKbps)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload2)
        writer.writeUInt8(fpsByte)
        writer.writeBytes(DjiStartStreamingMessagePayload.payload3)
        writer.writeBytes(djiPackUrl(url: rtmpUrl))
        return writer.data
    }
}

class DjiStopStreamingMessagePayload {
    static let payload = Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x02])

    func encode() -> Data {
        return DjiStopStreamingMessagePayload.payload
    }
}

class DjiConfigureMessagePayload {
    static let payload = Data([0x01, 0x01, 0x08, 0x00, 0x01])

    var imageStabilization: SettingsDjiDeviceImageStabilization

    init(imageStabilization: SettingsDjiDeviceImageStabilization) {
        self.imageStabilization = imageStabilization
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
        let writer = ByteArray()
        writer.writeBytes(DjiConfigureMessagePayload.payload)
        writer.writeUInt8(imageStabilizationByte)
        return writer.data
    }
}
