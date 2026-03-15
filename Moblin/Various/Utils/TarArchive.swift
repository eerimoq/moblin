import Foundation

struct TarArchiveEntry {
    let name: String
    let data: Data
}

enum TarArchive {
    private static let blockSize = 512

    static func create(entries: [TarArchiveEntry]) -> Data {
        var archive = Data()
        for entry in entries {
            archive.append(createHeader(name: entry.name, size: entry.data.count))
            archive.append(entry.data)
            let remainder = entry.data.count % blockSize
            if remainder != 0 {
                archive.append(Data(count: blockSize - remainder))
            }
        }
        archive.append(Data(count: blockSize * 2))
        return archive
    }

    static func extract(data: Data) -> [TarArchiveEntry] {
        var entries: [TarArchiveEntry] = []
        var offset = 0
        while offset + blockSize <= data.count {
            let headerData = data[offset ..< offset + blockSize]
            if headerData.allSatisfy({ $0 == 0 }) {
                break
            }
            guard let name = readString(data: headerData, offset: 0, length: 100) else {
                break
            }
            guard let size = readOctal(data: headerData, offset: 124, length: 12) else {
                break
            }
            offset += blockSize
            guard offset + size <= data.count else {
                break
            }
            entries.append(TarArchiveEntry(name: name, data: data[offset ..< offset + size]))
            offset += size
            let remainder = size % blockSize
            if remainder != 0 {
                offset += blockSize - remainder
            }
        }
        return entries
    }

    private static func createHeader(name: String, size: Int) -> Data {
        var header = Data(count: blockSize)
        writeString(data: &header, offset: 0, length: 100, value: name)
        writeOctal(data: &header, offset: 100, length: 8, value: 0o644)
        writeOctal(data: &header, offset: 108, length: 8, value: 0)
        writeOctal(data: &header, offset: 116, length: 8, value: 0)
        writeOctal(data: &header, offset: 124, length: 12, value: size)
        writeOctal(data: &header, offset: 136, length: 12, value: Int(Date().timeIntervalSince1970))
        header[156] = UInt8(ascii: "0")
        writeString(data: &header, offset: 257, length: 6, value: "ustar")
        writeString(data: &header, offset: 263, length: 2, value: "00")
        writeChecksum(header: &header)
        return header
    }

    private static func writeString(data: inout Data, offset: Int, length: Int, value: String) {
        let bytes = Array(value.utf8)
        for index in 0 ..< min(bytes.count, length) {
            data[offset + index] = bytes[index]
        }
    }

    private static func writeOctal(data: inout Data, offset: Int, length: Int, value: Int) {
        let octal = String(value, radix: 8)
        let padded = String(repeating: "0", count: max(0, length - 1 - octal.count)) + octal
        writeString(data: &data, offset: offset, length: length - 1, value: padded)
    }

    private static func writeChecksum(header: inout Data) {
        for index in 148 ..< 156 {
            header[index] = UInt8(ascii: " ")
        }
        var checksum = 0
        for byte in header {
            checksum += Int(byte)
        }
        writeOctal(data: &header, offset: 148, length: 7, value: checksum)
        header[155] = UInt8(ascii: " ")
    }

    private static func readString(data: Data, offset: Int, length: Int) -> String? {
        let start = data.startIndex + offset
        let end = start + length
        guard end <= data.endIndex else {
            return nil
        }
        let slice = data[start ..< end]
        guard let nullIndex = slice.firstIndex(of: 0) else {
            return String(bytes: slice, encoding: .utf8)
        }
        return String(bytes: data[start ..< nullIndex], encoding: .utf8)
    }

    private static func readOctal(data: Data, offset: Int, length: Int) -> Int? {
        guard let string = readString(data: data, offset: offset, length: length) else {
            return nil
        }
        return Int(string.trimmingCharacters(in: .whitespaces), radix: 8)
    }
}
