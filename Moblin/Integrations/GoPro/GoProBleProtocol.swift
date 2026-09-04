@preconcurrency import CoreBluetooth
import Foundation

enum GoProBleUuid {
    static let controlService = CBUUID(string: "FEA6")
    static let command = CBUUID(string: "B5F90072-AA8D-11E3-9046-0002A5D5C51B")
    static let commandResponse = CBUUID(string: "B5F90073-AA8D-11E3-9046-0002A5D5C51B")
    static let settings = CBUUID(string: "B5F90074-AA8D-11E3-9046-0002A5D5C51B")
    static let settingsResponse = CBUUID(string: "B5F90075-AA8D-11E3-9046-0002A5D5C51B")
    static let query = CBUUID(string: "B5F90076-AA8D-11E3-9046-0002A5D5C51B")
    static let queryResponse = CBUUID(string: "B5F90077-AA8D-11E3-9046-0002A5D5C51B")
    static let cameraManagementService = CBUUID(string: "B5F90090-AA8D-11E3-9046-0002A5D5C51B")
    static let networkManagement = CBUUID(string: "B5F90091-AA8D-11E3-9046-0002A5D5C51B")
    static let networkManagementResponse = CBUUID(string: "B5F90092-AA8D-11E3-9046-0002A5D5C51B")
}

struct GoProScanEntry {
    let ssid: String
    let signalStrengthBars: UInt64
    let signalFrequencyMhz: UInt64
    let flags: UInt64

    var isConfigured: Bool {
        flags & 0x02 != 0
    }

    var isUnsupportedType: Bool {
        flags & 0x10 != 0
    }

    var flagsDescription: String {
        let flagNames: [(UInt64, String)] = [
            (0x01, "authenticated"),
            (0x02, "configured"),
            (0x04, "best"),
            (0x08, "associated"),
            (0x10, "unsupported type"),
        ]
        let names = flagNames.filter { flags & $0.0 != 0 }.map(\.1)
        return "0x\(String(flags, radix: 16)) (\(names.isEmpty ? "open" : names.joined(separator: ", ")))"
    }
}

enum GoProProtobufValue {
    case varint(UInt64)
    case bytes(Data)
}

enum GoProBleProtocol {
    static func packets(for payload: Data, maximumPacketSize: Int = 20) -> [Data] {
        guard !payload.isEmpty, payload.count < 8191, maximumPacketSize >= 3 else {
            return []
        }
        let length = payload.count
        var packets: [Data] = []
        var offset = 0
        var first = Data([
            0x20 | UInt8((length >> 8) & 0x1F),
            UInt8(length & 0xFF),
        ])
        let firstCount = min(maximumPacketSize - first.count, length)
        first.append(payload.prefix(firstCount))
        packets.append(first)
        offset += firstCount
        while offset < length {
            var continuation = Data([0x80])
            let count = min(maximumPacketSize - 1, length - offset)
            continuation.append(payload[offset ..< offset + count])
            packets.append(continuation)
            offset += count
        }
        return packets
    }

    static func setPairingComplete() -> Data {
        var protobuf = Data()
        protobuf.appendVarint(field: 1, value: 0)
        protobuf.appendString(field: 2, value: "Moblin")
        return Data([0x03, 0x01]) + protobuf
    }

    static func startScan() -> Data {
        Data([0x02, 0x02])
    }

    static func getApEntries(scanId: UInt64, startIndex: UInt64, maximumEntries: UInt64) -> Data {
        var protobuf = Data()
        protobuf.appendVarint(field: 1, value: startIndex)
        protobuf.appendVarint(field: 2, value: maximumEntries)
        protobuf.appendVarint(field: 3, value: scanId)
        return Data([0x02, 0x03]) + protobuf
    }

    static func connectToProvisionedWifi(ssid: String) -> Data {
        var protobuf = Data()
        protobuf.appendString(field: 1, value: ssid)
        return Data([0x02, 0x04]) + protobuf
    }

    static func connectToWifi(ssid: String, password: String) -> Data {
        var protobuf = Data()
        protobuf.appendString(field: 1, value: ssid)
        protobuf.appendString(field: 2, value: password)
        protobuf.appendVarint(field: 10, value: 1)
        return Data([0x02, 0x05]) + protobuf
    }

    static func registerLiveStreamStatus() -> Data {
        var protobuf = Data()
        protobuf.appendVarint(field: 1, value: 1)
        protobuf.appendVarint(field: 1, value: 2)
        protobuf.appendVarint(field: 1, value: 4)
        return Data([0xF5, 0x74]) + protobuf
    }

    static func getLiveStreamStatus() -> Data {
        Data([0xF5, 0x74])
    }

    static func setLiveStreamMode(
        url: String,
        resolution: SettingsGoProLaunchLiveStreamResolution,
        bitrate: UInt32,
        lens: SettingsGoProLens
    ) -> Data {
        var protobuf = Data()
        protobuf.appendString(field: 1, value: url)
        protobuf.appendVarint(field: 2, value: 0)
        protobuf.appendVarint(field: 3, value: resolution.protobufValue)
        protobuf.appendVarint(field: 7, value: 800)
        protobuf.appendVarint(field: 8, value: UInt64(bitrate / 1000))
        protobuf.appendVarint(field: 9, value: UInt64(bitrate / 1000))
        if let lens = lens.protobufValue {
            protobuf.appendVarint(field: 10, value: lens)
        }
        return Data([0xF1, 0x79]) + protobuf
    }

    static func setShutter(on: Bool) -> Data {
        Data([0x01, 0x01, on ? 0x01 : 0x00])
    }

    static func keepAlive() -> Data {
        Data([0x5B, 0x01, 0x42])
    }

    static func getBatteryPercentage() -> Data {
        Data([0x13, 0x46])
    }

    static func scanEntries(in protobuf: Data) -> [GoProScanEntry] {
        protobufMessages(field: 3, in: protobuf).compactMap { entry in
            guard let ssid = protobufString(field: 1, in: entry) else {
                return nil
            }
            return GoProScanEntry(
                ssid: ssid,
                signalStrengthBars: protobufVarint(field: 2, in: entry) ?? 0,
                signalFrequencyMhz: protobufVarint(field: 4, in: entry) ?? 0,
                flags: protobufVarint(field: 5, in: entry) ?? 0
            )
        }
    }

    static func protobufVarint(field: Int, in data: Data) -> UInt64? {
        for entry in protobufFields(in: data) where entry.field == field {
            if case let .varint(value) = entry.value {
                return value
            }
        }
        return nil
    }

    static func protobufVarints(field: Int, in data: Data) -> [UInt64] {
        protobufFields(in: data).compactMap { entry in
            guard entry.field == field, case let .varint(value) = entry.value else {
                return nil
            }
            return value
        }
    }

    static func protobufString(field: Int, in data: Data) -> String? {
        for entry in protobufFields(in: data) where entry.field == field {
            if case let .bytes(value) = entry.value {
                return String(data: value, encoding: .utf8)
            }
        }
        return nil
    }

    static func protobufMessages(field: Int, in data: Data) -> [Data] {
        protobufFields(in: data).compactMap { entry in
            guard entry.field == field, case let .bytes(value) = entry.value else {
                return nil
            }
            return value
        }
    }

    private static func protobufFields(in data: Data) -> [(field: Int, value: GoProProtobufValue)] {
        var fields: [(field: Int, value: GoProProtobufValue)] = []
        var index = data.startIndex
        while index < data.endIndex {
            guard let key = readVarint(data, index: &index) else {
                return fields
            }
            let field = Int(key >> 3)
            let wireType = Int(key & 0x07)
            switch wireType {
            case 0:
                guard let value = readVarint(data, index: &index) else {
                    return fields
                }
                fields.append((field, .varint(value)))
            case 2:
                guard let length = readVarint(data, index: &index),
                      length <= UInt64(data.distance(from: index, to: data.endIndex))
                else {
                    return fields
                }
                let end = data.index(index, offsetBy: Int(length))
                fields.append((field, .bytes(Data(data[index ..< end]))))
                index = end
            default:
                guard skipField(wireType: wireType, data: data, index: &index) else {
                    return fields
                }
            }
        }
        return fields
    }

    private static func readVarint(_ data: Data, index: inout Data.Index) -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.endIndex, shift < 64 {
            let byte = data[index]
            index = data.index(after: index)
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
        }
        return nil
    }

    private static func skipField(wireType: Int, data: Data, index: inout Data.Index) -> Bool {
        let bytes: Int
        switch wireType {
        case 1:
            bytes = 8
        case 5:
            bytes = 4
        default:
            return false
        }
        guard data.distance(from: index, to: data.endIndex) >= bytes else {
            return false
        }
        index = data.index(index, offsetBy: bytes)
        return true
    }
}

final class GoProBleMessageAccumulator {
    private var expectedLength: Int?
    private var payload = Data()

    func append(packet: Data) -> Data? {
        guard let firstByte = packet.first else {
            return nil
        }
        if firstByte & 0x80 != 0 {
            guard expectedLength != nil else {
                reset()
                return nil
            }
            payload.append(packet.dropFirst())
        } else {
            reset()
            let headerType = (firstByte & 0x60) >> 5
            let headerLength: Int
            switch headerType {
            case 0:
                expectedLength = Int(firstByte & 0x1F)
                headerLength = 1
            case 1:
                guard packet.count >= 2 else {
                    return nil
                }
                expectedLength = (Int(firstByte & 0x1F) << 8) | Int(packet[1])
                headerLength = 2
            case 2:
                guard packet.count >= 3 else {
                    return nil
                }
                expectedLength = (Int(packet[1]) << 8) | Int(packet[2])
                headerLength = 3
            default:
                return nil
            }
            payload.append(packet.dropFirst(headerLength))
        }
        guard let expectedLength, payload.count >= expectedLength else {
            return nil
        }
        let message = Data(payload.prefix(expectedLength))
        reset()
        return message
    }

    private func reset() {
        expectedLength = nil
        payload.removeAll(keepingCapacity: true)
    }
}

private extension SettingsGoProLaunchLiveStreamResolution {
    var protobufValue: UInt64 {
        switch self {
        case .r480p:
            4
        case .r720p:
            7
        case .r1080p:
            12
        }
    }
}

extension SettingsGoProLens {
    var protobufValue: UInt64? {
        switch self {
        case .auto:
            nil
        case .wide:
            0
        case .linear:
            4
        case .superView:
            3
        }
    }
}

private extension Data {
    mutating func appendVarint(field: Int, value: UInt64) {
        appendVarint(UInt64(field << 3))
        appendVarint(value)
    }

    mutating func appendString(field: Int, value: String) {
        let bytes = Data(value.utf8)
        appendVarint(UInt64((field << 3) | 2))
        appendVarint(UInt64(bytes.count))
        append(bytes)
    }

    mutating func appendVarint(_ input: UInt64) {
        var value = input
        while value >= 0x80 {
            append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        }
        append(UInt8(value))
    }
}
