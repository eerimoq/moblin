import Foundation

// 7.3.2.1 Video parameter set RBSP syntax
struct HevcNalUnitVps {
    let data: Data

    init(reader: NalUnitReader) throws {
        data = try reader.readRawBytes()
    }

    func encode(writer: NalUnitWriter) {
        writer.writeRawBytes(data)
    }
}
