import Foundation

/**
 - see: https://en.wikipedia.org/wiki/Program-specific_information
 */
class MpegTsProgram {
    private static let reservedBits: UInt8 = 0x03
    private var pointerField: UInt8 = 0
    private var pointerFillerBytes = Data()
    var tableId: UInt8 = 0
    private var privateBit = false
    private var sectionLength: UInt16 = 0
    private var tableIdExtension: UInt16 = 1
    private var versionNumber: UInt8 = 0
    private var currentNextIndicator = true
    private var sectionNumber: UInt8 = 0
    private var lastSectionNumber: UInt8 = 0

    init() {}

    func encodeTableData() -> Data {
        return Data()
    }

    func packet(_ packetId: UInt16) -> MpegTsPacket {
        var packet = MpegTsPacket(id: packetId)
        packet.payloadUnitStartIndicator = true
        packet.setPayloadNoAdaptation(encode())
        return packet
    }

    private func encode() -> Data {
        let tableData = encodeTableData()
        sectionLength = UInt16(tableData.count) + 9
        let sectionSyntaxIndicator = !tableData.isEmpty
        let buffer = ByteArray()
            .writeUInt8(tableId)
            .writeUInt16(
                (sectionSyntaxIndicator ? 0x8000 : 0) |
                    (privateBit ? 0x4000 : 0) |
                    UInt16(MpegTsProgram.reservedBits) << 12 |
                    sectionLength
            )
            .writeUInt16(tableIdExtension)
            .writeUInt8(
                MpegTsProgram.reservedBits << 6 | versionNumber << 1 | (currentNextIndicator ? 1 : 0)
            )
            .writeUInt8(sectionNumber)
            .writeUInt8(lastSectionNumber)
            .writeBytes(tableData)
        let crc32 = CRC32.mpeg2.calculate(buffer.data)
        return Data([pointerField] + pointerFillerBytes) + buffer.writeUInt32(crc32).data
    }
}

final class MpegTsProgramAssociation: MpegTsProgram {
    var programs: [UInt16: UInt16] = [:]

    override func encodeTableData() -> Data {
        let buffer = ByteArray()
        for (number, programMapPID) in programs {
            buffer.writeUInt16(number).writeUInt16(programMapPID | 0xE000)
        }
        return buffer.data
    }
}

final class MpegTsProgramMap: MpegTsProgram {
    var programClockReferencePacketId: UInt16 = 0
    var programInfoLength: UInt16 = 0
    var elementaryStreamSpecificDatas: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableId = 2
    }

    override func encodeTableData() -> Data {
        var bytes = Data()
        elementaryStreamSpecificDatas.sort { (
            lhs: ElementaryStreamSpecificData,
            rhs: ElementaryStreamSpecificData
        ) -> Bool in
            lhs.elementaryPacketId < rhs.elementaryPacketId
        }
        for elementaryStreamSpecificData in elementaryStreamSpecificDatas {
            bytes.append(elementaryStreamSpecificData.encode())
        }
        return ByteArray()
            .writeUInt16(programClockReferencePacketId | 0xE000)
            .writeUInt16(programInfoLength | 0xF000)
            .writeBytes(bytes)
            .data
    }
}
