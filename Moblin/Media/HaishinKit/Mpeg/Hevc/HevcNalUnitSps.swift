import Foundation

// 7.3.2.2 Sequence parameter set RBSP syntax
struct HevcNalUnitSps {
    let data: Data

    init(reader: NalUnitReader) throws {
        data = try reader.readRawBytes()
    }

    func encode(writer: NalUnitWriter) {
        writer.writeRawBytes(data)
    }
}
