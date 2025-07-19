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
        let reader = ByteReader(data: data)
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
        let encoded = encode()
        packet.payload = encoded + Data(repeating: 0xFF, count: 184 - encoded.count)
        return packet
    }

    private func encode() -> Data {
        let tableData = encodeTableData()
        let sectionLength = UInt16(tableData.count) + 9
        let sectionSyntaxIndicator = !tableData.isEmpty
        let writer = ByteWriter()
        writer.writeUInt8(tableId)
        writer.writeUInt16(
            (sectionSyntaxIndicator ? 0x8000 : 0) |
                (privateBit ? 0x4000 : 0) |
                UInt16(MpegTsProgram.reservedBits) << 12 |
                sectionLength
        )
        writer.writeUInt16(tableIdExtension)
        writer.writeUInt8(
            MpegTsProgram.reservedBits << 6 | versionNumber << 1 | (currentNextIndicator ? 1 : 0)
        )
        writer.writeUInt8(sectionNumber)
        writer.writeUInt8(lastSectionNumber)
        writer.writeBytes(tableData)
        writer.writeUInt32(Crc32.mpeg2.calculate(writer.data))
        return Data([pointerField] + pointerFillerBytes) + writer.data
    }
}

final class MpegTsProgramAssociation: MpegTsProgram {
    var programs: [UInt16: UInt16] = [:]

    override func encodeTableData() -> Data {
        let writer = ByteWriter()
        for (programNumber, programId) in programs {
            writer.writeUInt16(programNumber)
            writer.writeUInt16(programId | 0xE000)
        }
        return writer.data
    }

    override func setTableData(data: Data) throws {
        let reader = ByteReader(data: data)
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
        let writer = ByteWriter()
        writer.writeUInt16(programClockReferencePacketId | 0xE000)
        writer.writeUInt16(programInfoLength | 0xF000)
        writer.writeBytes(encoded)
        return writer.data
    }

    override func setTableData(data: Data) throws {
        let reader = ByteReader(data: data)
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
