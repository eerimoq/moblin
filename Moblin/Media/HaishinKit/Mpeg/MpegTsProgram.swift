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
    private var tableIdExtension: UInt16 = 1
    private var versionNumber: UInt8 = 0
    private var currentNextIndicator = true
    private var sectionNumber: UInt8 = 0
    private var lastSectionNumber: UInt8 = 0

    init() {}

    init(data: Data) throws {
        let reader = ByteArray(data: data)
        pointerField = try reader.readUInt8()
        pointerFillerBytes = try reader.readBytes(Int(pointerField))
        tableId = try reader.readUInt8()
        let bytes: Data = try reader.readBytes(2)
        // let sectionSyntaxIndicator = (bytes[0] & 0x80) == 0x80
        privateBit = (bytes[0] & 0x40) == 0x40
        let sectionLength = UInt16(bytes[0] & 0x03) << 8 | UInt16(bytes[1])
        tableIdExtension = try reader.readUInt16()
        versionNumber = try reader.readUInt8()
        currentNextIndicator = (versionNumber & 0x01) == 0x01
        versionNumber = (versionNumber & 0b0011_1110) >> 1
        sectionNumber = try reader.readUInt8()
        lastSectionNumber = try reader.readUInt8()
        try setTableData(data: reader.readBytes(Int(sectionLength - 9)))
        // let crc32 = try reader.readUInt32()
    }

    func encodeTableData() -> Data {
        return Data()
    }

    func setTableData(data _: Data) throws {}

    func packet(_ packetId: UInt16) -> MpegTsPacket {
        var packet = MpegTsPacket(id: packetId)
        packet.payloadUnitStartIndicator = true
        packet.setPayloadNoAdaptation(encode())
        return packet
    }

    private func encode() -> Data {
        let tableData = encodeTableData()
        let sectionLength = UInt16(tableData.count) + 9
        let sectionSyntaxIndicator = !tableData.isEmpty
        let encoded = ByteArray()
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
        let crc32 = Crc32.mpeg2.calculate(encoded.data)
        return Data([pointerField] + pointerFillerBytes) + encoded.writeUInt32(crc32).data
    }
}

final class MpegTsProgramAssociation: MpegTsProgram {
    var programs: [UInt16: UInt16] = [:]

    override func encodeTableData() -> Data {
        let encoded = ByteArray()
        for (programNumber, programId) in programs {
            encoded.writeUInt16(programNumber).writeUInt16(programId | 0xE000)
        }
        return encoded.data
    }

    override func setTableData(data: Data) throws {
        let reader = ByteArray(data: data)
        while reader.bytesAvailable > 0 {
            let programNumber = try reader.readUInt16()
            let programId = try reader.readUInt16() & 0x1FFF
            programs[programNumber] = programId
        }
    }
}

final class MpegTsProgramMapping: MpegTsProgram {
    var programClockReferencePacketId: UInt16 = 0
    var programInfoLength: UInt16 = 0
    var elementaryStreamSpecificDatas: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableId = 2
    }

    override init(data: Data) throws {
        try super.init(data: data)
    }

    override func encodeTableData() -> Data {
        var encoded = Data()
        elementaryStreamSpecificDatas.sort { (
            lhs: ElementaryStreamSpecificData,
            rhs: ElementaryStreamSpecificData
        ) -> Bool in
            lhs.elementaryPacketId < rhs.elementaryPacketId
        }
        for elementaryStreamSpecificData in elementaryStreamSpecificDatas {
            encoded.append(elementaryStreamSpecificData.encode())
        }
        return ByteArray()
            .writeUInt16(programClockReferencePacketId | 0xE000)
            .writeUInt16(programInfoLength | 0xF000)
            .writeBytes(encoded)
            .data
    }

    override func setTableData(data: Data) throws {
        let reader = ByteArray(data: data)
        programClockReferencePacketId = try reader.readUInt16() & 0x1FFF
        programInfoLength = try reader.readUInt16() & 0x03FF
        reader.position += Int(programInfoLength)
        var position = 0
        while reader.bytesAvailable > 0 {
            position = reader.position
            let data = try ElementaryStreamSpecificData(data: reader.readBytes(reader.bytesAvailable))
            reader.position = position + ElementaryStreamSpecificData.fixedHeaderSize + Int(data.esInfoLength)
            elementaryStreamSpecificDatas.append(data)
        }
    }
}
