import Foundation

func createWav(sampleRate: Int, samples: [[Int16]]) -> Data? {
    let numberOfChannels = samples.count
    let dataSize: UInt32
    switch samples.count {
    case 1:
        dataSize = UInt32(samples[0].count * 2)
    case 2:
        guard samples[0].count == samples[1].count else {
            return nil
        }
        dataSize = UInt32(samples[0].count * 2 * 2)
    default:
        return nil
    }
    let writer = ByteWriter()
    writer.writeUTF8Bytes("RIFF")
    writer.writeUInt32Le(44 - 8 + dataSize)
    writer.writeUTF8Bytes("WAVE")
    writer.writeUTF8Bytes("fmt ")
    writer.writeUInt32Le(16)
    writer.writeUInt16Le(1) // int16
    writer.writeUInt16Le(UInt16(numberOfChannels))
    writer.writeUInt32Le(UInt32(sampleRate))
    writer.writeUInt32Le(0x02EE00) // 192 kbps
    writer.writeUInt16Le(4)
    writer.writeUInt16Le(16)
    writer.writeUTF8Bytes("data")
    writer.writeUInt32Le(dataSize)
    switch numberOfChannels {
    case 1:
        for sample in samples[0] {
            writer.writeUInt16Le(UInt16(bitPattern: sample))
        }
    case 2:
        for (sampleRight, sampleLeft) in zip(samples[0], samples[1]) {
            writer.writeUInt16Le(UInt16(bitPattern: sampleRight))
            writer.writeUInt16Le(UInt16(bitPattern: sampleLeft))
        }
    default:
        return nil
    }
    return writer.data
}
