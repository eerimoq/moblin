import Foundation

/**
 - see: https://en.wikipedia.org/wiki/Program-specific_information
 */
class MpegTsProgram {
    static let reservedBits: UInt8 = 0x03
    static let defaultTableIDExtension: UInt16 = 1
    var pointerField: UInt8 = 0
    var pointerFillerBytes = Data()
    var tableId: UInt8 = 0
    var sectionSyntaxIndicator = false
    var privateBit = false
    var sectionLength: UInt16 = 0
    var tableIdExtension: UInt16 = MpegTsProgram.defaultTableIDExtension
    var versionNumber: UInt8 = 0
    var currentNextIndicator = true
    var sectionNumber: UInt8 = 0
    var lastSectionNumber: UInt8 = 0
    var crc32: UInt32 = 0

    init() {}

    func encodeTableData() -> Data {
        return Data()
    }

    func packet(_ PID: UInt16) -> MpegTsPacket {
        var packet = MpegTsPacket(id: PID)
        packet.payloadUnitStartIndicator = true
        packet.setPayloadNoAdaptation(encode())
        return packet
    }

    private func encode() -> Data {
        let tableData = encodeTableData()
        sectionLength = UInt16(tableData.count) + 9
        sectionSyntaxIndicator = !tableData.isEmpty
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
        crc32 = CRC32.mpeg2.calculate(buffer.data)
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
    private static let tableID: UInt8 = 2
    var programClockReferencePacketId: UInt16 = 0
    var programInfoLength: UInt16 = 0
    var elementaryStreamSpecificDatas: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableId = MpegTsProgramMap.tableID
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
