import Foundation
import HaishinKit

class ADTSReader: Sequence {
    private var data: Data = .init()

    func read(_ data: Data) {
        self.data = data
    }

    func makeIterator() -> ADTSReaderIterator {
        return ADTSReaderIterator(data: data)
    }
}

struct ADTSReaderIterator: IteratorProtocol {
    private let data: Data
    private var cursor: Int = 0
    private var header: ADTSHeader = .init()

    init(data: Data) {
        self.data = data
    }

    mutating func next() -> Int? {
        guard cursor < data.count else {
            return nil
        }
        header.data = data.advanced(by: cursor)
        defer {
            cursor += Int(header.aacFrameLength)
        }
        return Int(header.aacFrameLength)
    }
}
