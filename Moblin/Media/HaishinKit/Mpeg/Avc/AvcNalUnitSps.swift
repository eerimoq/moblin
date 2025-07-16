import Foundation

struct AvcNalUnitSps {
    let data: Data

    init(reader: NalUnitReader) throws {
        data = try reader.readRawBytes()
    }

    func encode(writer: NalUnitWriter) {
        writer.writeRawBytes(data)
    }
}
