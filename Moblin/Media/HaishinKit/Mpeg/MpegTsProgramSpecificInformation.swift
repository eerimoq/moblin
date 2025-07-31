import Foundation

private enum TableIdentifier: UInt8 {
    case programAssociation = 0
    case programMapping = 2
}

/**
 - see: https://en.wikipedia.org/wiki/Program-specific_information
 */
class MpegTsProgramSpecificInformation {
    private static let reservedBits: UInt8 = 0x03
    private var pointerField: UInt8 = 0
    private var pointerSkippedBytes = Data()
    var tableId: UInt8 = TableIdentifier.programAssociation.rawValue
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
        pointerSkippedBytes = try reader.readBytes(Int(pointerField))
        tableId = try reader.readUInt8()
        let value = try reader.readUInt16()
        let sectionSyntaxIndicator = (value & 0x8000) == 0x8000
        privateBit = (value & 0x4000) == 0x4000
        var sectionLength = Int(value & 0x3FF)
        if sectionSyntaxIndicator {
            tableIdExtension = try reader.readUInt16()
            let value = try reader.readUInt8()
            currentNextIndicator = (value & 0x01) == 0x01
            versionNumber = (value & 0b0011_1110) >> 1
            sectionNumber = try reader.readUInt8()
            lastSectionNumber = try reader.readUInt8()
            sectionLength -= 5
        }
        try decodeSectionData(data: reader.readBytes(sectionLength - 4))
    }

    fileprivate func encodeSectionData() -> Data {
        return Data()
    }

    fileprivate func decodeSectionData(data _: Data) throws {}

    func packet(_ packetId: UInt16) -> MpegTsPacket {
        var packet = MpegTsPacket(id: packetId)
        packet.payloadUnitStartIndicator = true
        let encoded = encode()
        packet.payload = encoded + Data(repeating: 0xFF, count: 184 - encoded.count)
        return packet
    }

    private func encode() -> Data {
        let sectionData = encodeSectionData()
        let sectionLength = UInt16(sectionData.count) + 9
        let sectionSyntaxIndicator = !sectionData.isEmpty
        let writer = ByteWriter()
        writer.writeUInt8(tableId)
        var value: UInt16 = 0
        value |= (sectionSyntaxIndicator ? 0x8000 : 0)
        value |= (privateBit ? 0x4000 : 0)
        value |= UInt16(MpegTsProgramSpecificInformation.reservedBits) << 12
        value |= sectionLength
        writer.writeUInt16(value)
        writer.writeUInt16(tableIdExtension)
        var value2: UInt8 = 0
        value2 |= MpegTsProgramSpecificInformation.reservedBits << 6
        value2 |= versionNumber << 1
        value2 |= (currentNextIndicator ? 1 : 0)
        writer.writeUInt8(value2)
        writer.writeUInt8(sectionNumber)
        writer.writeUInt8(lastSectionNumber)
        writer.writeBytes(sectionData)
        writer.writeUInt32(Crc32.mpeg2.calculate(writer.data))
        return Data([pointerField] + pointerSkippedBytes) + writer.data
    }
}

final class MpegTsProgramAssociation: MpegTsProgramSpecificInformation {
    var programs: [UInt16: UInt16] = [:]

    override fileprivate func encodeSectionData() -> Data {
        let writer = ByteWriter()
        for (programNumber, programId) in programs {
            writer.writeUInt16(programNumber)
            writer.writeUInt16(programId | 0xE000)
        }
        return writer.data
    }

    override fileprivate func decodeSectionData(data: Data) throws {
        let reader = ByteReader(data: data)
        while reader.bytesAvailable > 0 {
            let programNumber = try reader.readUInt16()
            let programId = try reader.readUInt16() & 0x1FFF
            programs[programNumber] = programId
        }
    }
}

final class MpegTsProgramMapping: MpegTsProgramSpecificInformation {
    var programClockReferencePacketId: UInt16 = 0
    var elementaryStreamSpecificDatas: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableId = TableIdentifier.programMapping.rawValue
    }

    override init(data: Data) throws {
        try super.init(data: data)
    }

    override fileprivate func encodeSectionData() -> Data {
        var encoded = Data()
        elementaryStreamSpecificDatas.sort { $0.elementaryPacketId < $1.elementaryPacketId }
        for elementaryStreamSpecificData in elementaryStreamSpecificDatas {
            encoded.append(elementaryStreamSpecificData.encode())
        }
        let writer = ByteWriter()
        writer.writeUInt16(programClockReferencePacketId | 0xE000)
        writer.writeUInt16(0xF000)
        writer.writeBytes(encoded)
        return writer.data
    }

    override fileprivate func decodeSectionData(data: Data) throws {
        let reader = ByteReader(data: data)
        programClockReferencePacketId = try reader.readUInt16() & 0x1FFF
        let programInfoLength = try reader.readUInt16() & 0x03FF
        try reader.skipBytes(Int(programInfoLength))
        while reader.bytesAvailable > 0 {
            try elementaryStreamSpecificDatas.append(ElementaryStreamSpecificData(reader: reader))
        }
    }
}
