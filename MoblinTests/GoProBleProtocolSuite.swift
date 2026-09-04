import Foundation
@testable import Moblin
import Testing

struct GoProBleProtocolSuite {
    @Test
    func packetizesSinglePacketCommand() {
        let packets = GoProBleProtocol.packets(for: GoProBleProtocol.setShutter(on: true))
        #expect(packets == [Data([0x20, 0x03, 0x01, 0x01, 0x01])])
    }

    @Test
    func packetizesAndAccumulatesLongMessage() throws {
        let message = Data((0 ..< 64).map(UInt8.init))
        let packets = GoProBleProtocol.packets(for: message)
        #expect(packets.count == 4)
        #expect(packets[0].count == 20)
        #expect(Data(packets[0].prefix(2)) == Data([0x20, 0x40]))
        #expect(packets.dropFirst().allSatisfy { $0.first == 0x80 })

        let accumulator = GoProBleMessageAccumulator()
        for packet in packets.dropLast() {
            #expect(accumulator.append(packet: packet) == nil)
        }
        #expect(try accumulator.append(packet: #require(packets.last)) == message)
    }

    @Test
    func buildsPairingAndWifiCommands() {
        #expect(GoProBleProtocol.setPairingComplete().hexString() == "0301080012064d6f626c696e")
        #expect(
            GoProBleProtocol.connectToWifi(ssid: "Moblin", password: "secret").hexString()
                == "02050a064d6f626c696e12067365637265745001"
        )
    }

    @Test
    func buildsScanCommands() {
        #expect(GoProBleProtocol.startScan().hexString() == "0202")
        #expect(
            GoProBleProtocol.getApEntries(scanId: 3, startIndex: 0, maximumEntries: 100).hexString()
                == "0203080010641803"
        )
        #expect(
            GoProBleProtocol.connectToProvisionedWifi(ssid: "Moblin").hexString()
                == "02040a064d6f626c696e"
        )
    }

    @Test
    func buildsLiveStreamModeCommand() {
        #expect(
            GoProBleProtocol.setLiveStreamMode(
                url: "rtmp://a",
                resolution: .r1080p,
                bitrate: 6_000_000,
                lens: .auto
            )
            .hexString() == "f1790a0872746d703a2f2f611000180c38a00640f02e48f02e"
        )
        #expect(
            GoProBleProtocol.setLiveStreamMode(
                url: "rtmp://a",
                resolution: .r1080p,
                bitrate: 6_000_000,
                lens: .linear
            )
            .hexString() == "f1790a0872746d703a2f2f611000180c38a00640f02e48f02e5004"
        )
    }

    @Test
    func parsesVarintWhileSkippingOtherFields() {
        let response = Data([0x12, 0x03, 0x61, 0x62, 0x63, 0x08, 0x06])
        #expect(GoProBleProtocol.protobufVarint(field: 1, in: response) == 6)
    }

    @Test
    func parsesScanEntries() {
        let response = Data([
            0x08, 0x01, 0x10, 0x03, 0x1A, 0x0E, 0x0A, 0x05, 0x4F, 0x74,
            0x68, 0x65, 0x72, 0x10, 0x02, 0x20, 0xBC, 0x28, 0x28, 0x01,
            0x1A, 0x0F, 0x0A, 0x06, 0x4D, 0x6F, 0x62, 0x6C, 0x69, 0x6E,
            0x10, 0x03, 0x20, 0x85, 0x13, 0x28, 0x03,
        ])
        let entries = GoProBleProtocol.scanEntries(in: response)
        #expect(entries.count == 2)
        #expect(entries.first?.ssid == "Other")
        #expect(entries.first?.signalStrengthBars == 2)
        #expect(entries.first?.signalFrequencyMhz == 5180)
        #expect(entries.first?.isConfigured == false)
        #expect(entries.last?.ssid == "Moblin")
        #expect(entries.last?.signalFrequencyMhz == 2437)
        #expect(entries.last?.isConfigured == true)
        #expect(entries.last?.isUnsupportedType == false)
    }
}
