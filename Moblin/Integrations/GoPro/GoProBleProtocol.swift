@preconcurrency import CoreBluetooth
import Foundation
import SwiftProtobuf

let goProControlServiceId = CBUUID(string: "FEA6")
let goProCommandId = CBUUID(string: "B5F90072-AA8D-11E3-9046-0002A5D5C51B")
let goProCommandResponseId = CBUUID(string: "B5F90073-AA8D-11E3-9046-0002A5D5C51B")
let goProSettingsId = CBUUID(string: "B5F90074-AA8D-11E3-9046-0002A5D5C51B")
let goProSettingsResponseId = CBUUID(string: "B5F90075-AA8D-11E3-9046-0002A5D5C51B")
let goProQueryId = CBUUID(string: "B5F90076-AA8D-11E3-9046-0002A5D5C51B")
let goProQueryResponseId = CBUUID(string: "B5F90077-AA8D-11E3-9046-0002A5D5C51B")
let goProCameraManagementServiceId = CBUUID(string: "B5F90090-AA8D-11E3-9046-0002A5D5C51B")
let goProNetworkManagementId = CBUUID(string: "B5F90091-AA8D-11E3-9046-0002A5D5C51B")
let goProNetworkManagementResponseId = CBUUID(string: "B5F90092-AA8D-11E3-9046-0002A5D5C51B")

func goProBlePackets(payload: Data, maximumPacketSize: Int = 20) -> [Data] {
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

func goProPairingCompleteMessage() -> Data {
    var request = OpenGopro_RequestPairingFinish()
    request.result = .success
    request.phoneName = "Moblin"
    return Data([0x03, 0x01]) + request.encoded()
}

func goProStartScanMessage() -> Data {
    Data([0x02, 0x02]) + OpenGopro_RequestStartScan().encoded()
}

func goProGetApEntriesMessage(scanId: Int32, startIndex: Int32, maximumEntries: Int32) -> Data {
    var request = OpenGopro_RequestGetApEntries()
    request.startIndex = startIndex
    request.maxEntries = maximumEntries
    request.scanID = scanId
    return Data([0x02, 0x03]) + request.encoded()
}

func goProConnectToProvisionedWifiMessage(ssid: String) -> Data {
    var request = OpenGopro_RequestConnect()
    request.ssid = ssid
    return Data([0x02, 0x04]) + request.encoded()
}

func goProConnectToWifiMessage(ssid: String, password: String) -> Data {
    var request = OpenGopro_RequestConnectNew()
    request.ssid = ssid
    request.password = password
    request.bypassEulaCheck = true
    return Data([0x02, 0x05]) + request.encoded()
}

func goProRegisterLiveStreamStatusMessage() -> Data {
    var request = OpenGopro_RequestGetLiveStreamStatus()
    request.registerLiveStreamStatus = [
        .registerLiveStreamStatusStatus,
        .registerLiveStreamStatusError,
        .registerLiveStreamStatusBitrate,
    ]
    return Data([0xF5, 0x74]) + request.encoded()
}

func goProGetLiveStreamStatusMessage() -> Data {
    Data([0xF5, 0x74]) + OpenGopro_RequestGetLiveStreamStatus().encoded()
}

func goProSetLiveStreamModeMessage(
    url: String,
    resolution: SettingsGoProLaunchLiveStreamResolution,
    bitrate: UInt32,
    lens: SettingsGoProLens
) -> Data {
    var request = OpenGopro_RequestSetLiveStreamMode()
    request.url = url
    request.encode = false
    request.windowSize = resolution.toProtobuf()
    request.minimumBitrate = 800
    request.maximumBitrate = Int32(bitrate / 1000)
    request.startingBitrate = Int32(bitrate / 1000)
    if let lens = lens.toProtobuf() {
        request.lens = lens
    }
    return Data([0xF1, 0x79]) + request.encoded()
}

func goProSetShutterMessage(on: Bool) -> Data {
    Data([0x01, 0x01, on ? 0x01 : 0x00])
}

func goProKeepAliveMessage() -> Data {
    Data([0x5B, 0x01, 0x42])
}

func goProGetBatteryPercentageMessage() -> Data {
    Data([0x13, 0x46])
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

extension OpenGopro_ResponseGetApEntries.ScanEntry {
    func isConfigured() -> Bool {
        scanEntryFlags & Int32(OpenGopro_EnumScanEntryFlags.scanFlagConfigured.rawValue) != 0
    }

    func isUnsupportedType() -> Bool {
        scanEntryFlags & Int32(OpenGopro_EnumScanEntryFlags.scanFlagUnsupportedType.rawValue) != 0
    }
}

private extension SwiftProtobuf.Message {
    func encoded() -> Data {
        (try? serializedData()) ?? Data()
    }
}

private extension SettingsGoProLaunchLiveStreamResolution {
    func toProtobuf() -> OpenGopro_EnumWindowSize {
        switch self {
        case .r480p:
            .windowSize480
        case .r720p:
            .windowSize720
        case .r1080p:
            .windowSize1080
        }
    }
}

extension SettingsGoProLens {
    func toProtobuf() -> OpenGopro_EnumLens? {
        switch self {
        case .auto:
            nil
        case .wide:
            .lensWide
        case .linear:
            .lensLinear
        case .superView:
            .lensSuperview
        }
    }
}
