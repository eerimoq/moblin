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
    var tableData = Data()
    var crc32: UInt32 = 0

    init() {}

    init?(_ data: Data) {
        self.data = data
    }

    func packet(_ PID: UInt16) -> MpegTsPacket {
        var packet = MpegTsPacket(pid: PID)
        packet.payloadUnitStartIndicator = true
        packet.setPayloadNoAdaptation(data)
        return packet
    }

    var data: Data {
        get {
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
                    MpegTsProgram.reservedBits << 6 |
                        versionNumber << 1 |
                        (currentNextIndicator ? 1 : 0)
                )
                .writeUInt8(sectionNumber)
                .writeUInt8(lastSectionNumber)
                .writeBytes(tableData)
            crc32 = CRC32.mpeg2.calculate(buffer.data)
            return Data([pointerField] + pointerFillerBytes) + buffer.writeUInt32(crc32).data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                pointerField = try buffer.readUInt8()
                pointerFillerBytes = try buffer.readBytes(Int(pointerField))
                tableId = try buffer.readUInt8()
                let bytes: Data = try buffer.readBytes(2)
                sectionSyntaxIndicator = (bytes[0] & 0x80) == 0x80
                privateBit = (bytes[0] & 0x40) == 0x40
                sectionLength = UInt16(bytes[0] & 0x03) << 8 | UInt16(bytes[1])
                tableIdExtension = try buffer.readUInt16()
                versionNumber = try buffer.readUInt8()
                currentNextIndicator = (versionNumber & 0x01) == 0x01
                versionNumber = (versionNumber & 0b0011_1110) >> 1
                sectionNumber = try buffer.readUInt8()
                lastSectionNumber = try buffer.readUInt8()
                tableData = try buffer.readBytes(Int(sectionLength - 9))
                crc32 = try buffer.readUInt32()
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

final class TSProgramAssociation: MpegTsProgram {
    var programs: [UInt16: UInt16] = [:]

    override var tableData: Data {
        get {
            let buffer = ByteArray()
            for (number, programMapPID) in programs {
                buffer.writeUInt16(number).writeUInt16(programMapPID | 0xE000)
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                for _ in 0 ..< newValue.count / 4 {
                    try programs[buffer.readUInt16()] = try buffer.readUInt16() & 0x1FFF
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

final class TSProgramMap: MpegTsProgram {
    static let tableID: UInt8 = 2

    var PCRPID: UInt16 = 0
    var programInfoLength: UInt16 = 0
    var elementaryStreamSpecificData: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableId = TSProgramMap.tableID
    }

    override init?(_ data: Data) {
        super.init()
        self.data = data
    }

    override var tableData: Data {
        get {
            var bytes = Data()
            elementaryStreamSpecificData.sort { (
                lhs: ElementaryStreamSpecificData,
                rhs: ElementaryStreamSpecificData
            ) -> Bool in
                lhs.elementaryPID < rhs.elementaryPID
            }
            for essd in elementaryStreamSpecificData {
                bytes.append(essd.data)
            }
            return ByteArray()
                .writeUInt16(PCRPID | 0xE000)
                .writeUInt16(programInfoLength | 0xF000)
                .writeBytes(bytes)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                PCRPID = try buffer.readUInt16() & 0x1FFF
                programInfoLength = try buffer.readUInt16() & 0x03FF
                buffer.position += Int(programInfoLength)
                var position = 0
                while buffer.bytesAvailable > 0 {
                    position = buffer.position
                    guard let data = try ElementaryStreamSpecificData(buffer
                        .readBytes(buffer.bytesAvailable))
                    else {
                        break
                    }
                    buffer.position = position + ElementaryStreamSpecificData
                        .fixedHeaderSize + Int(data.esInfoLength)
                    elementaryStreamSpecificData.append(data)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
