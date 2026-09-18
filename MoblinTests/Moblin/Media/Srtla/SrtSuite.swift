import Foundation
@testable import Moblin
import Testing

private func makeNakPacket(_ sns: [UInt32]) -> Data {
    let writer = ByteWriter()
    writer.writeBytes(Data(count: 16))
    for sn in sns {
        writer.writeUInt32(sn)
    }
    return writer.data
}

struct SrtSuite {
    @Test
    func processNakSingleAndRange() {
        var sns: [UInt32] = []
        processSrtNak(packet: makeNakPacket([7, 0x8000_0000 | 10, 12, 20])) { sn in
            sns.append(sn)
        }
        #expect(sns == [7, 10, 11, 12, 20])
    }

    @Test
    func processNakTooBigRangeIsIgnored() {
        var sns: [UInt32] = []
        processSrtNak(packet: makeNakPacket([0x8000_0000, 0x7FFF_FFFF, 5])) { sn in
            sns.append(sn)
        }
        #expect(sns == [5])
    }

    @Test
    func processNakReversedRangeIsIgnored() {
        var sns: [UInt32] = []
        processSrtNak(packet: makeNakPacket([0x8000_0000 | 10, 3, 5])) { sn in
            sns.append(sn)
        }
        #expect(sns == [5])
    }

    @Test
    func processNakTruncatedRange() {
        var sns: [UInt32] = []
        processSrtNak(packet: makeNakPacket([1, 0x8000_0000 | 10])) { sn in
            sns.append(sn)
        }
        #expect(sns == [1])
    }
}
