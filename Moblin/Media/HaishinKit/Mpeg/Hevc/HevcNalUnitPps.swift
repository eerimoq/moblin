import Foundation

// 7.3.2.3 Picture parameter set RBSP syntax
struct HevcNalUnitPps {
    let data: Data

    init(reader: NalUnitReader) throws {
        data = try reader.readRawBytes()
    }

    func encode(writer: NalUnitWriter) {
        writer.writeRawBytes(data)
    }
}
