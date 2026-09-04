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

let goProPairingFeatureId: UInt8 = 0x03
let goProPairingFinishActionId: UInt8 = 0x01
let goProPairingFinishResponseId: UInt8 = 0x81
let goProNetworkFeatureId: UInt8 = 0x02
let goProStartScanActionId: UInt8 = 0x02
let goProStartScanResponseId: UInt8 = 0x82
let goProGetApEntriesActionId: UInt8 = 0x03
let goProGetApEntriesResponseId: UInt8 = 0x83
let goProConnectActionId: UInt8 = 0x04
let goProConnectResponseId: UInt8 = 0x84
let goProConnectNewActionId: UInt8 = 0x05
let goProConnectNewResponseId: UInt8 = 0x85
let goProScanningNotificationId: UInt8 = 0x0B
let goProProvisioningNotificationId: UInt8 = 0x0C
let goProShutterCommandId: UInt8 = 0x01
let goProLiveStreamCommandFeatureId: UInt8 = 0xF1
let goProSetLiveStreamModeActionId: UInt8 = 0x79
let goProSetLiveStreamModeResponseId: UInt8 = 0xF9
let goProLiveStreamQueryFeatureId: UInt8 = 0xF5
let goProGetLiveStreamStatusActionId: UInt8 = 0x74
let goProGetLiveStreamStatusResponseId: UInt8 = 0xF4
let goProLiveStreamStatusNotificationId: UInt8 = 0xF5
let goProGetStatusQueryId: UInt8 = 0x13
let goProBatteryPercentageStatusId: UInt8 = 0x46
let goProKeepAliveSettingId: UInt8 = 0x5B
let goProResponseSuccessStatus: UInt8 = 0x00
let goProMaximumApEntriesPerRequest: Int32 = 100

private let goProKeepAliveValue: UInt8 = 0x42
private let goProMaximumPacketSize = 20
private let goProMaximumPayloadSize = 8191
private let goProContinuationPacketHeader: UInt8 = 0x80
private let goProGeneralPacketHeaderType: UInt8 = 0
private let goProExtended13PacketHeaderType: UInt8 = 1
private let goProExtended16PacketHeaderType: UInt8 = 2
private let goProPacketHeaderTypeMask: UInt8 = 0x60
private let goProPacketHeaderTypeShift: UInt8 = 5
private let goProPacketHeaderLengthMask: UInt8 = 0x1F

func goProBlePackets(payload: Data, maximumPacketSize: Int = goProMaximumPacketSize) -> [Data] {
    guard !payload.isEmpty, payload.count < goProMaximumPayloadSize, maximumPacketSize >= 3 else {
        return []
    }
    let length = payload.count
    var packets: [Data] = []
    var offset = 0
    var first = Data([
        (goProExtended13PacketHeaderType << goProPacketHeaderTypeShift)
            | UInt8((length >> 8) & Int(goProPacketHeaderLengthMask)),
        UInt8(length & 0xFF),
    ])
    let firstCount = min(maximumPacketSize - first.count, length)
    first.append(payload.prefix(firstCount))
    packets.append(first)
    offset += firstCount
    while offset < length {
        var continuation = Data([goProContinuationPacketHeader])
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
    return Data([goProPairingFeatureId, goProPairingFinishActionId]) + request.encoded()
}

func goProStartScanMessage() -> Data {
    Data([goProNetworkFeatureId, goProStartScanActionId]) + OpenGopro_RequestStartScan().encoded()
}

func goProGetApEntriesMessage(scanId: Int32, startIndex: Int32, maximumEntries: Int32) -> Data {
    var request = OpenGopro_RequestGetApEntries()
    request.startIndex = startIndex
    request.maxEntries = maximumEntries
    request.scanID = scanId
    return Data([goProNetworkFeatureId, goProGetApEntriesActionId]) + request.encoded()
}

func goProConnectToProvisionedWifiMessage(ssid: String) -> Data {
    var request = OpenGopro_RequestConnect()
    request.ssid = ssid
    return Data([goProNetworkFeatureId, goProConnectActionId]) + request.encoded()
}

func goProConnectToWifiMessage(ssid: String, password: String) -> Data {
    var request = OpenGopro_RequestConnectNew()
    request.ssid = ssid
    request.password = password
    request.bypassEulaCheck = true
    return Data([goProNetworkFeatureId, goProConnectNewActionId]) + request.encoded()
}

func goProRegisterLiveStreamStatusMessage() -> Data {
    var request = OpenGopro_RequestGetLiveStreamStatus()
    request.registerLiveStreamStatus = [
        .registerLiveStreamStatusStatus,
        .registerLiveStreamStatusError,
        .registerLiveStreamStatusBitrate,
    ]
    return Data([goProLiveStreamQueryFeatureId, goProGetLiveStreamStatusActionId]) + request.encoded()
}

func goProGetLiveStreamStatusMessage() -> Data {
    Data([goProLiveStreamQueryFeatureId, goProGetLiveStreamStatusActionId])
        + OpenGopro_RequestGetLiveStreamStatus().encoded()
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
    return Data([goProLiveStreamCommandFeatureId, goProSetLiveStreamModeActionId]) + request.encoded()
}

func goProSetShutterMessage(on: Bool) -> Data {
    Data([goProShutterCommandId, 1, on ? 1 : 0])
}

func goProKeepAliveMessage() -> Data {
    Data([goProKeepAliveSettingId, 1, goProKeepAliveValue])
}

func goProGetBatteryPercentageMessage() -> Data {
    Data([goProGetStatusQueryId, goProBatteryPercentageStatusId])
}

final class GoProBleMessageAccumulator {
    private var expectedLength: Int?
    private var payload = Data()

    func append(packet: Data) -> Data? {
        guard let firstByte = packet.first else {
            return nil
        }
        if firstByte & goProContinuationPacketHeader != 0 {
            guard expectedLength != nil else {
                reset()
                return nil
            }
            payload.append(packet.dropFirst())
        } else {
            reset()
            let headerType = (firstByte & goProPacketHeaderTypeMask) >> goProPacketHeaderTypeShift
            let headerLength: Int
            switch headerType {
            case goProGeneralPacketHeaderType:
                expectedLength = Int(firstByte & goProPacketHeaderLengthMask)
                headerLength = 1
            case goProExtended13PacketHeaderType:
                guard packet.count >= 2 else {
                    return nil
                }
                expectedLength = (Int(firstByte & goProPacketHeaderLengthMask) << 8) | Int(packet[1])
                headerLength = 2
            case goProExtended16PacketHeaderType:
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
